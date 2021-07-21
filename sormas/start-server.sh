#!/bin/bash
# entering exit immediately mode
set -e

function stop_payara() {
  echo "Stopping server ${DOMAIN_NAME}." >> ${LOG_FILE_PATH}/server.log
  ${PAYARA_HOME}/bin/asadmin stop-domain --domaindir ${DOMAINS_HOME}
  exit
}

function check_db() {
  psql -h ${DB_HOST} -U ${SORMAS_POSTGRES_USER} ${DB_NAME} --no-align --tuples-only --quiet --command="SELECT count(*) FROM pg_database WHERE datname='${DB_NAME}';" 2>/dev/null || echo "0"
}

function check_java() {
  ps -ef | grep /usr/lib/jvm/zulu-8-amd64/bin/java | grep -v grep | wc -l
}

function start_sormas() {
  # for some reasons, we have to "open" the linked server.log after a few seconds to get payara to use it.
  ( sleep 20 && echo >> ${LOG_FILE_PATH}/server.log ) &
  ${PAYARA_HOME}/bin/asadmin start-domain --domaindir ${DOMAINS_HOME} ${DOMAIN_NAME}
}

function delete_jdbc_connection_pool() {
  echo "Deleting jdbc-resource $1"
  ${ASADMIN} list-jdbc-resources | grep -q "$1"
  if [ $? -ne 0 ];then
    cat ${DOMAIN_DIR}/config/domain.xml
    echo
    echo "jdbc-resource $1 not found. Exiting!!"
    exit 1
  fi
  ${ASADMIN} delete-jdbc-resource "$1"

  ${ASADMIN} list-jdbc-connection-pools | grep -q "$2"
  echo "Deleting jdbc-connection-pool $2"
  if [ $? -ne 0 ];then
    cat ${DOMAIN_DIR}/config/domain.xml
    echo
    echo "jdbc-connection-pool $2 not found. Exiting!!"
    exit 1
  fi
  ${ASADMIN} delete-jdbc-connection-pool "$2"
}

export PGPASSWORD=${SORMAS_POSTGRES_PASSWORD}
SLEEP=10
COUNT=0
while [ $(check_db) -ne 1 ];do
  echo "Waiting for ${DB_NAME} DB to get ready ..."
  sleep ${SLEEP}
  COUNT=$(( ${COUNT} + 1 ))
  if [ ${COUNT} -gt 9 ];then
    echo "DB ${DB_NAME} is not reachable after ${COUNT} attempts. Exiting!"
    exit 1
  fi
done
unset PGPASSWORD

echo "AS_ADMIN_NEWPASSWORD=${AS_ADMIN_NEWPASSWORD}" > ./newpwfile.txt
echo -e "AS_ADMIN_PASSWORD=\nAS_ADMIN_NEWPASSWORD=${AS_ADMIN_NEWPASSWORD}" > ./oldpwfile.txt

ROOT_PREFIX=
# make sure to update payara-sormas script when changing the user name
USER_NAME=payara

PAYARA_HOME=${ROOT_PREFIX}/opt/payara5
DOMAINS_HOME=${ROOT_PREFIX}/opt/domains
TEMP_DIR=${ROOT_PREFIX}/opt/${DOMAIN_NAME}/temp
DOCUMENTS_DIR=${ROOT_PREFIX}/opt/${DOMAIN_NAME}/documents
GENERATED_DIR=${ROOT_PREFIX}/opt/${DOMAIN_NAME}/generated
CUSTOM_DIR=${ROOT_PREFIX}/opt/${DOMAIN_NAME}/custom

DEPLOY_PATH=/tmp/${DOMAIN_NAME}
DOWNLOADS_PATH=/var/www/${DOMAIN_NAME}/downloads

PORT_BASE=6000
PORT_ADMIN=6048
DOMAIN_DIR=${DOMAINS_HOME}/${DOMAIN_NAME}
PROPERTIES_FILE=${DOMAIN_DIR}/sormas.properties
LOG_FILE_PATH=${DOMAIN_DIR}/logs
LOG_FILE_NAME=configure_`date +"%Y-%m-%d_%H-%M-%S"`.log

ASADMIN="${PAYARA_HOME}/bin/asadmin --port ${PORT_ADMIN}"

# first delete all deployed applications - fresh start
rm -rf ${DOMAIN_DIR}/applications
rm -rf ${DOMAIN_DIR}/generated
rm -rf ${DOMAIN_DIR}/logs/*
rm -rf ${DOMAIN_DIR}/osgi-cache/*
rm -rf ${DOMAIN_DIR}/autodeploy/.autodeploystatus
rm -f ${DOMAIN_DIR}/autodeploy/*

# link server.log with stdout of PID 1
# ln -sf /proc/1/fd/1 ${LOG_FILE_PATH}/server.log

start_sormas

echo "Configuring domain and database connection..."

# JVM settings
set +e
${ASADMIN} delete-jvm-options -Xmx4096m
${ASADMIN} create-jvm-options -Xmx${JVM_MAX}
set -e
# Proxy settings
if [ ! -z "$PROXY_HOST" ];then
  echo "Updating Proxy Settings"
${ASADMIN} create-system-properties --target server-config org.jboss.resteasy.jaxrs.client.proxy.host=${PROXY_HOST}
${ASADMIN} create-system-properties --target server-config org.jboss.resteasy.jaxrs.client.proxy.port=${PROXY_PORT}
${ASADMIN} create-system-properties --target server-config org.jboss.resteasy.jaxrs.client.proxy.scheme=${PROXY_SCHEME}
fi
# JDBC pool
echo "Configuring JDBC pool"
delete_jdbc_connection_pool "jdbc/${DOMAIN_NAME}DataPool" "${DOMAIN_NAME}DataPool"
${ASADMIN} create-jdbc-connection-pool --restype javax.sql.ConnectionPoolDataSource --datasourceclassname org.postgresql.ds.PGConnectionPoolDataSource --isconnectvalidatereq true --validationmethod custom-validation --validationclassname org.glassfish.api.jdbc.validation.PostgresConnectionValidation --maxpoolsize ${DB_JDBC_MAXPOOLSIZE} --property "portNumber=5432:databaseName=${DB_NAME}:serverName=${DB_HOST}:user=${SORMAS_POSTGRES_USER}:password=${SORMAS_POSTGRES_PASSWORD}" ${DOMAIN_NAME}DataPool
${ASADMIN} create-jdbc-resource --connectionpoolid ${DOMAIN_NAME}DataPool jdbc/${DOMAIN_NAME}DataPool

# Pool for audit log
echo "Configuring audit log"
delete_jdbc_connection_pool "jdbc/AuditlogPool" "${DOMAIN_NAME}AuditlogPool"
${ASADMIN} create-jdbc-connection-pool --restype javax.sql.XADataSource --datasourceclassname org.postgresql.xa.PGXADataSource --isconnectvalidatereq true --validationmethod custom-validation --validationclassname org.glassfish.api.jdbc.validation.PostgresConnectionValidation --maxpoolsize ${DB_JDBC_MAXPOOLSIZE} --property "portNumber=5432:databaseName=${DB_NAME_AUDIT}:serverName=${DB_HOST}:user=${SORMAS_POSTGRES_USER}:password=${SORMAS_POSTGRES_PASSWORD}" ${DOMAIN_NAME}AuditlogPool
${ASADMIN} create-jdbc-resource --connectionpoolid ${DOMAIN_NAME}AuditlogPool jdbc/AuditlogPool

set +e
${ASADMIN} delete-javamail-resource mail/MailSession
set -e

${ASADMIN} create-javamail-resource --mailhost ${MAIL_HOST} --mailuser ${EMAIL_SENDER_NAME} --fromaddress ${EMAIL_SENDER_ADDRESS} --auth ${SMTP_AUTH_ENABLED} --enabled ${EMAIL_NOTIFICATION_ENABLED} --property  "mail.smtp.port=${SMTP_PORT}:mail.smtp.auth=${SMTP_AUTH_ENABLED}" mail/MailSession

# Fix for https://github.com/hzi-braunschweig/SORMAS-Project/issues/1759
${ASADMIN} set configs.config.server-config.thread-pools.thread-pool.http-thread-pool.max-thread-pool-size=500
# set FQDN for sormas domain
${ASADMIN} set configs.config.server-config.http-service.virtual-server.server.hosts=${SORMAS_SERVER_URL}

# Set admin password before start
echo "Configuring admin password"
set +e
${ASADMIN} --user admin --passwordfile ./oldpwfile.txt change-admin-password --domaindir ${DOMAINS_HOME} --domain_name ${DOMAIN_NAME}
${ASADMIN} --user admin --passwordfile ./newpwfile.txt enable-secure-admin
set -e
# switch to json log formatting if JSON_LOGGIN is set to true
if [ "$JSON_LOGGING" == true ]; then
echo "Enabling logging in JSON format"
${ASADMIN} set-log-attributes com.sun.enterprise.server.logging.GFFileHandler.formatter='fish.payara.enterprise.server.logging.JSONLogFormatter'
fi

# update keycloak client secrets
if [ ! -z "$AUTHENTICATION_PROVIDER" -a "$AUTHENTICATION_PROVIDER" = "KEYCLOAK" ];then
  echo "Updating Keycloak connection"
  ${ASADMIN} set-config-property --propertyName=payara.security.openid.clientId --propertyValue=sormas-ui --source=domain
  ${ASADMIN} set-config-property --propertyName=payara.security.openid.scope --propertyValue=openid --source=domain
  ${ASADMIN} set-config-property --propertyName=payara.security.openid.providerURI --propertyValue=https://${SORMAS_SERVER_URL}/keycloak/auth/realms/SORMAS --source=domain
  ${ASADMIN} set-config-property --propertyName=payara.security.openid.clientSecret --propertyValue=${KEYCLOAK_SORMAS_UI_SECRET} --source=domain
  ${ASADMIN} set-config-property --propertyName=payara.security.openid.providerURI --propertyValue=https://${SORMAS_SERVER_URL}/keycloak/auth/realms/SORMAS --source=domain
  ${ASADMIN} set-config-property --propertyName=sormas.rest.security.oidc.json --propertyValue="{\"realm\":\"SORMAS\",\"auth-server-url\":\"https://${SORMAS_SERVER_URL}/keycloak/auth\",\"ssl-required\":\"external\",\"resource\":\"sormas-rest\",\"credentials\":{\"secret\":\"${KEYCLOAK_SORMAS_REST_SECRET}\"},\"confidential-port\":0,\"principal-attribute\":\"preferred_username\",\"enable-basic-auth\":true}" --source=domain
  ${ASADMIN} set-config-property --propertyName=sormas.backend.security.oidc.json --propertyValue="{\"realm\":\"SORMAS\",\"auth-server-url\":\"https://${SORMAS_SERVER_URL}/keycloak/auth/\",\"ssl-required\":\"external\",\"resource\":\"sormas-backend\",\"credentials\":{\"secret\":\"${KEYCLOAK_SORMAS_BACKEND_SECRET}\"},\"confidential-port\":0}" --source=domain
fi

${PAYARA_HOME}/bin/asadmin stop-domain --domaindir ${DOMAINS_HOME}
chown -R ${USER_NAME}:${USER_NAME} ${DOMAIN_DIR}

# LOGBACK logger
#  enable email sending when recipient is not empty
if [[ ! -z "${LOG_RECIPIENT_ADDRESS}" ]]; then
    sed -i 's|<!-- <appender-ref ref="EMAIL_ERROR" /> -->|<appender-ref ref="EMAIL_ERROR" />|' ${DOMAIN_DIR}/config/logback.xml
fi
sed -i "s/MAIL_HOST/$MAIL_HOST/" ${DOMAIN_DIR}/config/logback.xml
sed -i "s/SMTP_PORT/$SMTP_PORT/" ${DOMAIN_DIR}/config/logback.xml
sed -i "s/SMTP_USER/$SMTP_USER/" ${DOMAIN_DIR}/config/logback.xml
sed -i "s/SMTP_PASSWORD/$SMTP_PASSWORD/" ${DOMAIN_DIR}/config/logback.xml
sed -i "s/SMTP_STARTTLS/$SMTP_STARTTLS/" ${DOMAIN_DIR}/config/logback.xml
sed -i "s/SMTP_SSL/$SMTP_SSL/" ${DOMAIN_DIR}/config/logback.xml
sed -i "s/SMTP_ASYNC_SENDING/$SMTP_ASYNC_SENDING/" ${DOMAIN_DIR}/config/logback.xml
sed -i "s/LOG_RECIPIENT_ADDRESS/$LOG_RECIPIENT_ADDRESS/" ${DOMAIN_DIR}/config/logback.xml
sed -i "s/LOG_SENDER_ADDRESS/$LOG_SENDER_ADDRESS/" ${DOMAIN_DIR}/config/logback.xml
sed -i "s/LOG_SUBJECT/$SORMAS_SERVER_URL $LOG_SUBJECT/" ${DOMAIN_DIR}/config/logback.xml

#Edit properties
sed -i "/^createDefaultEntities/d " ${DOMAIN_DIR}/sormas.properties
sed -i "/^country.locale/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^country.name/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^country.epidprefix/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^csv.separator/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^email.sender.address/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^email.sender.name/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^country.center.latitude/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^country.center.longitude/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^map.zoom/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^app.url/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^namesimilaritythreshold/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^duplicatechecks.excludepersonsonlylinkedtoarchivedentries/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^map.usecountrycenter/d" ${DOMAIN_DIR}/sormas.properties

echo -e "\ncreateDefaultEntities=${CREATE_DEFAULT_ENTITIES}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ncountry.locale=${LOCALE}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ncountry.name=${COUNTRY_NAME}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ncountry.epidprefix=${EPIDPREFIX}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ncsv.separator=${SEPARATOR}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\nemail.sender.address=${EMAIL_SENDER_ADDRESS}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\nemail.sender.name=${EMAIL_SENDER_NAME}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ncountry.center.latitude=${LATITUDE}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ncountry.center.longitude=${LONGITUDE}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\nmap.zoom=${MAP_ZOOM}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\napp.url=https://${SORMAS_SERVER_URL}/downloads/release/sormas-${SORMAS_VERSION}-release.apk;" >>${DOMAIN_DIR}/sormas.properties
echo -e "\nnamesimilaritythreshold=${NAMESIMILARITYTHRESHOLD}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\nduplicatechecks.excludepersonsonlylinkedtoarchivedentries=${DC_EXCLUDE_ARCHIVED_PERSON_ENTRIES}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\nmap.usecountrycenter=${MAP_USECOUNTRYCENTER}" >>${DOMAIN_DIR}/sormas.properties

#------------------GEOCODING
sed -i "/^geocodingServiceUrlTemplate/d " ${DOMAIN_DIR}/sormas.properties
sed -i "/^geocodingLongitudeJsonPath/d " ${DOMAIN_DIR}/sormas.properties
sed -i "/^geocodingLatitudeJsonPath/d " ${DOMAIN_DIR}/sormas.properties

echo -e "\ngeocodingServiceUrlTemplate=${GEO_TEMPLATE}" >>${DOMAIN_DIR}/sormas.properties
echo -e "geocodingLongitudeJsonPath=${GEO_LONG_TEMPLATE}" >>${DOMAIN_DIR}/sormas.properties
echo -e "geocodingLatitudeJsonPath=${GEO_LAT_TEMPLATE}" >>${DOMAIN_DIR}/sormas.properties
sed -i "s/\${GEO_UUID}/${GEO_UUID}/" ${DOMAIN_DIR}/sormas.properties

sed -i "s/\#rscript.executable=.*/rscript.executable=Rscript/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/\#\s\devmode=.*/devmode=${DEVMODE}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/\#\s\daysAfterCaseGetsArchived=.*/daysAfterCaseGetsArchived=${CASEARCHIVEDAYS}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/\#\s\daysAfterEventGetsArchived=.*/daysAfterEventGetsArchived=${EVENTARCHIVEDAYS}/" ${DOMAIN_DIR}/sormas.properties

#------------------PIA CONFIG
if [ ! -z "$PIA_URL" ];then
sed -i "s/\#interface.pia.url=.*/interface.pia.url=${PIA_URL}/" ${DOMAIN_DIR}/sormas.properties
echo -e "\ninterface.symptomjournal.url = ${SJ_URL}" >>${DOMAIN_DIR}/sormas.properties
echo "interface.symptomjournal.authurl = ${SJ_AUTH}" >>${DOMAIN_DIR}/sormas.properties
echo "interface.symptomjournal.clientid = ${SJ_CLIENTID}" >>${DOMAIN_DIR}/sormas.properties
echo "interface.symptomjournal.secret = ${SJ_SECRET}" >>${DOMAIN_DIR}/sormas.properties
echo "interface.symptomjournal.defaultuser.username = ${SJ_DEFAULT_USERNAME}" >>${DOMAIN_DIR}/sormas.properties
echo "interface.symptomjournal.defaultuser.password = ${SJ_DEFAULT_PASSWORD}" >>${DOMAIN_DIR}/sormas.properties
fi

#------------------CLIMEDO CONFIG
sed -i "/^interface\.patientdiary\.url/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.probandsurl/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.authurl/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.email/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.password/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.defaultuser\.username/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.defaultuser\.password/d" "${DOMAIN_DIR}/sormas.properties"

if [ ! -z "$PATIENTDIARY_ENABLED" ];then
echo -e "\ninterface.patientdiary.url=${PD_URL}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ninterface.patientdiary.probandsurl=${PD_PROBANDS_URL}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ninterface.patientdiary.authurl=${PD_AUTH_URL}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ninterface.patientdiary.email=${PD_EMAIL}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ninterface.patientdiary.password=${PD_PASSWORD}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ninterface.patientdiary.defaultuser.username=${PD_DEFAULT_USERNAME}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ninterface.patientdiary.defaultuser.password=${PD_DEFAULT_PASSWORD}" >>${DOMAIN_DIR}/sormas.properties
fi

#------------------BRANDING CONFIG
if [ ! -z "$CUSTOMBRANDING_ENABLED" ];then
sed -i "s/\#custombranding=false/custombranding=${CUSTOMBRANDING_ENABLED}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/\#custombranding.name=.*/custombranding.name=${CUSTOMBRANDING_NAME}/" ${DOMAIN_DIR}/sormas.properties
echo -e "\ncustombranding.logo.path=${CUSTOMBRANDING_LOGO_PATH}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ncustombranding.useloginsidebar=${CUSTOMBRANDING_USE_LOGINSIDEBAR}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\ncustombranding.loginbackground.path=${CUSTOMBRANDING_LOGINBACKGROUND_PATH}" >>${DOMAIN_DIR}/sormas.properties
fi

### SORMAS CENTRAL ###
echo "Sormas Central"
if [ ! -z  "$SORMAS_CENTRAL_ENABLED" ]; then
  echo "Sormas Central enabled"
  sed -i -E "s/#?central.oidc.url=.*/central.oidc.url=${CENTRAL_OIDC_URL}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?central.redis.host=.*/central.redis.host=${CENTRAL_REDIS_HOST}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?central.redis.keystorePath=.*/central.redis.keystorePath=${CENTRAL_REDIS_KEYSTOREPATH}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?central.redis.keystorePassword=.*/central.redis.keystorePassword=${CENTRAL_REDIS_KEYSTOREPASSWORD}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?central.redis.truststorePath=.*/central.redis.truststorePath=\/tmp\/s2s\/redis\/redis.truststore.p12/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?central.redis.truststorePassword=.*/central.redis.truststorePassword=password/" "${PROPERTIES_FILE}"
fi

#### SORMAS2SORMAS ###
echo "SORMAS2SORMAS"
if [ ! -z  "$SORMAS2SORMAS_ENABLED" ]; then
  echo "SORMAS2SORMAS enabled"
  sed -i -E "s~#?sormas2sormas.path=.*~sormas2sormas.path=${SORMAS2SORMAS_PATH}~" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.id=.*/sormas2sormas.id=${SORMAS2SORMAS_ID}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.keystoreName=.*/sormas2sormas.keystoreName=${SORMAS2SORMAS_KEYSTORENAME}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.keystorePass=.*/sormas2sormas.keystorePass=${SORMAS2SORMAS_KEYPASSWORD}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.rootCaAlias=.*/sormas2sormas.rootCaAlias=${SORMAS2SORMAS_ROOTCAALIAS}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.truststoreName=.*/sormas2sormas.truststoreName=${SORMAS2SORMAS_TRUSTSTORENAME}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.truststorePass=.*/sormas2sormas.truststorePass=${SORMAS2SORMAS_TRUSTSTOREPASSWORD}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.oidc.realm=.*/sormas2sormas.oidc.realm=${SORMAS2SORMAS_OIDC_REALM}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.oidc.clientId=.*/sormas2sormas.oidc.clientId=${SORMAS2SORMAS_OIDC_CLIENTID}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.oidc.clientSecret=.*/sormas2sormas.oidc.clientSecret=${SORMAS2SORMAS_OIDC_CLIENTSECRET}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.redis.clientName=.*/sormas2sormas.redis.clientName=${SORMAS2SORMAS_REDIS_CLIENTNAME}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.redis.clientPassword=.*/sormas2sormas.redis.clientPassword=${SORMAS2SORMAS_REDIS_CLIENTPASSWORD}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.retainCaseExternalToken=.*/sormas2sormas.retainCaseExternalToken=${SORMAS2SORMAS_RETAINCASEEXTERNALTOKEN}/" "${PROPERTIES_FILE}"
fi


#------------------AUTHENTICATION PROVIDER CONFIG
if [ ! -z "$AUTHENTICATION_PROVIDER" ];then
if [ ! -z "$AUTHENTICATION_PROVIDER" -a "$AUTHENTICATION_PROVIDER" = "KEYCLOAK" ];then
echo -e "\nauthentication.provider.userSyncAtStartup=true" >>${DOMAIN_DIR}/sormas.properties
fi
sed -i "/^authentication.provider=/{h;s/=.*/=${AUTHENTICATION_PROVIDER}/};\${x;/^$/{s//authentication.provider=${AUTHENTICATION_PROVIDER}/;H};x}" ${DOMAIN_DIR}/sormas.properties
fi


#------------------SURVNET CONFIG
sed -i "/^survnet\.url/d" "${DOMAIN_DIR}/sormas.properties"
if [ ! -z "$SURVNET_ENABLED" ];then
echo -e "\nsurvnet.url=${SURVNET_URL}" >>${DOMAIN_DIR}/sormas.properties
fi

#------------------DEMIS CONFIG
if [ ! -z "$DEMIS_ENABLED" ];then
set +e
cp -a /tmp/${DOMAIN_NAME}/config/demis/. ${DOMAIN_DIR}/config/
set -e
echo -e "\ninterface.demis.jndiName=java:global/sormas-demis-adapter-${DEMIS_VERSION}/DemisExternalLabResultsFacade" >>${DOMAIN_DIR}/sormas.properties

echo -e "debuginfo.enabled=${DEBUGINFO_ENABLED}" >${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nfhir.basepath=${FHIR_BASEPATH}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nidp.tokenendpoint=${IDP_TOKENENDPOINT}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nidp.lab.tokenendpoint=${IDP_LAB_TOKENENDPOINT}" >>${DOMAIN_DIR}/config/demis-adapter.properties

echo -e "\nidp.oegd.proxy=${IDP_OEGD_PROXY}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nidp.oegd.clientid=${IDP_OEGD_CLIENTID}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nidp.oegd.secret=${IDP_OEGD_SECRET}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nidp.oegd.username=${IDP_OEGD_USERNAME}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nidp.oegd.truststore=${IDP_OEGD_TRUSTSTORE}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nidp.oegd.truststorepassword=${IDP_OEGD_TRUSTSTOREPASSWORD}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nidp.oegd.authcertkeystore=${IDP_OEGD_AUTHCERTKEYSTORE}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nidp.oegd.authcertpassword=${IDP_OEGD_AUTHCERTPASSWORD}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nidp.oegd.authcertalias=${IDP_OEGD_AUTHCERTALIAS}" >>${DOMAIN_DIR}/config/demis-adapter.properties

echo -e "\nidp.oegd.outdated.authcertkeystore=${IDP_OEGD_OUTDATED_AUTHCERTKEYSTORE}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nidp.oegd.outdated.authcertpassword=${IDP_OEGD_OUTDATED_AUTHCERTPASSWORD}" >>${DOMAIN_DIR}/config/demis-adapter.properties

echo -e "\nconnect.timeout.ms=${CONNECT_TIMEOUT_MS}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nconnection.request.timeout.ms=${CONNECTION_REQUEST_TIMEOUT_MS}" >>${DOMAIN_DIR}/config/demis-adapter.properties
echo -e "\nsocket.timeout.ms=${SOCKET_TIMEOUT_MS}" >>${DOMAIN_DIR}/config/demis-adapter.properties

fi

# import R library
Rscript -e 'library(epicontacts)'
Rscript -e 'library(RPostgreSQL)'
Rscript -e 'library(visNetwork)'
Rscript -e 'library(dplyr)'

# put deployments into place
for APP in $(ls ${DOMAIN_DIR}/deployments/*.ear 2>/dev/null);do
  cp ${APP} ${DOMAIN_DIR}/autodeploy
done
sleep 5
for APP in $(ls ${DOMAIN_DIR}/deployments/*.war 2>/dev/null);do
  cp ${APP} ${DOMAIN_DIR}/autodeploy
done

SLEEP=10
COUNT=0
while [ $(check_java) -gt 0 ];do
  echo "Waiting for sormas server shutdown ..."
  sleep ${SLEEP}
  if [ ${COUNT} -eq 5 ];then
    ${PAYARA_HOME}/bin/asadmin stop-domain --domaindir ${DOMAINS_HOME}
  fi
  COUNT=$(( ${COUNT} + 1 ))
  if [ ${COUNT} -gt 9 ];then
    echo "Sormas server still running. Exiting!"
    exit 1
  fi
done

if [ ! -z "$AUTHENTICATION_PROVIDER" -a "$AUTHENTICATION_PROVDER" != "SORMAS" ];then
  echo "Updating payara keystores"
  set +e
  keytool -storepass ${CACERTS_PASS} -importcert -trustcacerts -destkeystore ${DOMAIN_DIR}/config/cacerts.jks -file /tmp/certs/sormas-docker-test.com.crt -alias sormas-docker-test.com -noprompt
  openssl pkcs12 -export -in /tmp/certs/sormas-docker-test.com.crt -inkey /tmp/certs/sormas-docker-test.com.key -out sormas-docker-test.com.p12 -name sormas-docker-test.com -password pass:${KEYSTORE_PASS}
  keytool -storepass ${KEYSTORE_PASS} -importkeystore -destkeystore ${DOMAIN_DIR}/config/keystore.jks -srckeystore sormas-docker-test.com.p12 -srcstoretype PKCS12 -srcstorepass changeit -alias sormas-docker-test.com -noprompt
  set -e
fi

echo "Server setup completed."
echo
echo "Starting server ${DOMAIN_NAME}."

start_sormas

echo "Changing rw-permissions of groups and others"
chmod 600 /opt/domains/sormas/sormas.properties /opt/domains/sormas/config/domain.xml /opt/domains/sormas/config/domain.xml.bak /opt/domains/sormas/logs/server.log

#sleep 60
#echo >> ${LOG_FILE_PATH}/server.log

# on SIGTERM (POD shutdown) stop payara and exit
# trap stop_payara SIGTERM
tail -f $LOG_FILE_PATH/server.log
# # keep running
# while true
# do
#     sleep 5
# done
