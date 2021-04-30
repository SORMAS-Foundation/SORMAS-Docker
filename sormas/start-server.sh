#!/bin/bash

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
${ASADMIN} delete-jvm-options -Xmx4096m
${ASADMIN} create-jvm-options -Xmx${JVM_MAX}

# Proxy settings
if [ ! -z "$PROXY_HOST" ];then
  echo "Updating Proxy Settings"
${ASADMIN} create-system-properties --target server-config org.jboss.resteasy.jaxrs.client.proxy.host=${PROXY_HOST}
${ASADMIN} create-system-properties --target server-config org.jboss.resteasy.jaxrs.client.proxy.port=${PROXY_PORT}
${ASADMIN} create-system-properties --target server-config org.jboss.resteasy.jaxrs.client.proxy.scheme=${PROXY_SCHEME}
fi
# JDBC pool
delete_jdbc_connection_pool "jdbc/${DOMAIN_NAME}DataPool" "${DOMAIN_NAME}DataPool"
${ASADMIN} create-jdbc-connection-pool --restype javax.sql.ConnectionPoolDataSource --datasourceclassname org.postgresql.ds.PGConnectionPoolDataSource --isconnectvalidatereq true --validationmethod custom-validation --validationclassname org.glassfish.api.jdbc.validation.PostgresConnectionValidation --maxpoolsize ${DB_JDBC_MAXPOOLSIZE} --property "portNumber=5432:databaseName=${DB_NAME}:serverName=${DB_HOST}:user=${SORMAS_POSTGRES_USER}:password=${SORMAS_POSTGRES_PASSWORD}" ${DOMAIN_NAME}DataPool
${ASADMIN} create-jdbc-resource --connectionpoolid ${DOMAIN_NAME}DataPool jdbc/${DOMAIN_NAME}DataPool

# Pool for audit log
delete_jdbc_connection_pool "jdbc/AuditlogPool" "${DOMAIN_NAME}AuditlogPool"
${ASADMIN} create-jdbc-connection-pool --restype javax.sql.XADataSource --datasourceclassname org.postgresql.xa.PGXADataSource --isconnectvalidatereq true --validationmethod custom-validation --validationclassname org.glassfish.api.jdbc.validation.PostgresConnectionValidation --maxpoolsize ${DB_JDBC_MAXPOOLSIZE} --property "portNumber=5432:databaseName=${DB_NAME_AUDIT}:serverName=${DB_HOST}:user=${SORMAS_POSTGRES_USER}:password=${SORMAS_POSTGRES_PASSWORD}" ${DOMAIN_NAME}AuditlogPool
${ASADMIN} create-jdbc-resource --connectionpoolid ${DOMAIN_NAME}AuditlogPool jdbc/AuditlogPool

${ASADMIN} delete-javamail-resource mail/MailSession
${ASADMIN} create-javamail-resource --mailhost ${MAIL_HOST} --mailuser "sormas" --fromaddress ${MAIL_FROM} mail/MailSession

# Fix for https://github.com/hzi-braunschweig/SORMAS-Project/issues/1759
${ASADMIN} set configs.config.server-config.thread-pools.thread-pool.http-thread-pool.max-thread-pool-size=500
# set FQDN for sormas domain
${ASADMIN} set configs.config.server-config.http-service.virtual-server.server.hosts=${SORMAS_SERVER_URL}

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

#Edit properties
sed -i "/^createDefaultEntities/d " ${DOMAIN_DIR}/sormas.properties
echo -e "\ncreateDefaultEntities=${CREATE_DEFAULT_ENTITIES}" >>${DOMAIN_DIR}/sormas.properties
sed -i "s/country.locale=.*/country.locale=${LOCALE}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/country.name=.*/country.name=${COUNTRY_NAME}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/country.epidprefix=.*/country.epidprefix=${EPIDPREFIX}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/#csv.separator=.*/csv.separator=/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/csv.separator=.*/csv.separator=${SEPARATOR}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/#email.sender.address=.*/email.sender.address=/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/email.sender.address=.*/email.sender.address=${EMAIL_SENDER_ADDRESS}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/#email.sender.name=.*/email.sender.name=/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/email.sender.name=.*/email.sender.name=${EMAIL_SENDER_NAME}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/country.center.latitude=.*/country.center.latitude=${LATITUDE}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/country.center.longitude=.*/country.center.longitude=${LONGITUDE}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/map.zoom=.*/map.zoom=${MAP_ZOOM}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s;app.url=.*;app.url=https://${SORMAS_SERVER_URL}/downloads/release/sormas-${SORMAS_VERSION}-release.apk;" ${DOMAIN_DIR}/sormas.properties
sed -i "s/\#namesimilaritythreshold=.*/namesimilaritythreshold=${NAMESIMILARITYTHRESHOLD}/" ${DOMAIN_DIR}/sormas.properties
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

#------------------SORMAS2SORMAS CONFIG
sed -i "/^sormas2sormas\.serverAccessDataFileName/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^sormas2sormas\.keystoreName/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^sormas2sormas\.keystorePass/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^sormas2sormas\.truststoreName/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^sormas2sormas\.truststorePass/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^sormas2sormas\.path/d" "${DOMAIN_DIR}/sormas.properties"

if [ ! -z "$SORMAS2SORMAS_ENABLED" ];then
sed -i "s/\#sormas2sormas.retainCaseExternalToken=.*/sormas2sormas.retainCaseExternalToken=${SORMAS2SORMAS_RETAINCASEEXTERNALTOKEN}/" ${DOMAIN_DIR}/sormas.properties
echo -e "\nsormas2sormas.serverAccessDataFileName=${SORMAS_SERVER_URL}-server-access-data.csv" >>${DOMAIN_DIR}/sormas.properties
echo -e "\nsormas2sormas.keystoreName=${SORMAS2SORMAS_KEYSTORENAME}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\nsormas2sormas.keystorePass=${SORMAS2SORMAS_KEYPASSWORD}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\nsormas2sormas.truststoreName=${SORMAS2SORMAS_TRUSTSTORENAME}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\nsormas2sormas.truststorePass=${SORMAS2SORMAS_TRUSTSTOREPASSWORD}" >>${DOMAIN_DIR}/sormas.properties
echo -e "\nsormas2sormas.path=${SORMAS2SORMAS_DIR}" >>${DOMAIN_DIR}/sormas.properties

export SORMAS2SORMAS_DIR=/opt/sormas/sormas2sormas
export SORMAS_ORG_ID=${SORMAS_ORG_ID}
export SORMAS_ORG_NAME=${SORMAS_ORG_NAME}
export SORMAS_HOST_NAME=${SORMAS_SERVER_URL}
export SORMAS_HTTPS_PORT=443
export SORMAS_S2S_CERT_PASS=${SORMAS_S2S_CERT_PASS}
export SORMAS_S2S_REST_PASSWORD=${SORMAS_S2S_REST_PASSWORD}
export S2S_NON_INTERACTIVE

  if [ ! -f /opt/sormas/sormas2sormas/${SORMAS_SERVER_URL}.sormas2sormas.keystore.p12 ];then
    bash /opt/sormas/s2s-generate-cert.sh
  fi

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
cp -a /tmp/${DOMAIN_NAME}/config/demis/. ${DOMAIN_DIR}/config/
echo -e "\ninterface.demis.jndiName=java:global/sormas-demis-adapter-1.4.1/DemisExternalLabResultsFacade" >>${DOMAIN_DIR}/sormas.properties

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

echo -e "\ntime.persistence.path=${TIME_PERSISTENCE_PATH}" >>${DOMAIN_DIR}/config/demis-adapter.properties
mkdir ${TIME_PERSISTENCE_PATH}
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
  keytool -storepass ${CACERTS_PASS} -importcert -trustcacerts -destkeystore ${DOMAIN_DIR}/config/cacerts.jks -file /tmp/certs/sormas-docker-test.com.crt -alias sormas-docker-test.com -noprompt
  openssl pkcs12 -export -in /tmp/certs/sormas-docker-test.com.crt -inkey /tmp/certs/sormas-docker-test.com.key -out sormas-docker-test.com.p12 -name sormas-docker-test.com -password pass:${KEYSTORE_PASS}
  keytool -storepass ${KEYSTORE_PASS} -importkeystore -destkeystore ${DOMAIN_DIR}/config/keystore.jks -srckeystore sormas-docker-test.com.p12 -srcstoretype PKCS12 -srcstorepass changeit -alias sormas-docker-test.com -noprompt
fi

echo "Server setup completed."
echo
echo "Starting server ${DOMAIN_NAME}."

start_sormas

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
