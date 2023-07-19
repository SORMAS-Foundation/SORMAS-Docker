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

if [ "${GLOWROOT_ENABLED}" == "true" ];then
  echo "Enable Glowroot"
  ${ASADMIN} create-jvm-options "-javaagent\:/opt/glowroot/glowroot.jar"
else
  echo "Do not Enable Glowroot"
fi

set -e
# Proxy settings
if [ ! -z "$PROXY_HOST" ];then
  echo "Updating Proxy Settings"
  ${ASADMIN} create-system-properties --target server-config org.jboss.resteasy.jaxrs.client.proxy.host=${PROXY_HOST}
  ${ASADMIN} create-system-properties --target server-config org.jboss.resteasy.jaxrs.client.proxy.port=${PROXY_PORT}
  ${ASADMIN} create-system-properties --target server-config org.jboss.resteasy.jaxrs.client.proxy.scheme=${PROXY_SCHEME}
  if [ ! -z "$SORMAS_CENTRAL_ENABLED" ]; then
    set +e
    # manipulet environments to remove everything except the hostnames
    central_etcd_ssl_cert=${CENTRAL_ETCD_HOST%:443}
    central_keycloak_ssl_cert=${CENTRAL_OIDC_URL#https:\\/\\/}
    keytool -storepass ${CACERTS_PASS} -importcert -trustcacerts -destkeystore ${DOMAIN_DIR}/config/cacerts.jks -file /tmp/certs/${central_etcd_ssl_cert}.crt -alias s2s-central-etcd -noprompt
    keytool -storepass ${CACERTS_PASS} -importcert -trustcacerts -destkeystore ${DOMAIN_DIR}/config/cacerts.jks -file /tmp/certs/${central_keycloak_ssl_cert}.crt -alias s2s-central-keycloak -noprompt
    set -e
  fi
fi
# JDBC pool
echo "Configuring JDBC pool"
if [ ! -z DB_JDBC_IDLE_TIMEOUT ] && [ ! -z DB_JDBC_MAXPOOLSIZE ] ; then
  delete_jdbc_connection_pool "jdbc/${DOMAIN_NAME}DataPool" "${DOMAIN_NAME}DataPool"
  ${ASADMIN} create-jdbc-connection-pool --restype javax.sql.ConnectionPoolDataSource --datasourceclassname org.postgresql.ds.PGConnectionPoolDataSource --isconnectvalidatereq true --validationmethod custom-validation --validationclassname org.glassfish.api.jdbc.validation.PostgresConnectionValidation --maxpoolsize ${DB_JDBC_MAXPOOLSIZE} --idletimeout ${DB_JDBC_IDLE_TIMEOUT} --property "portNumber=5432:databaseName=${DB_NAME}:serverName=${DB_HOST}:user=${SORMAS_POSTGRES_USER}:password=${SORMAS_POSTGRES_PASSWORD}"  ${DOMAIN_NAME}DataPool
  ${ASADMIN} create-jdbc-resource --connectionpoolid ${DOMAIN_NAME}DataPool jdbc/${DOMAIN_NAME}DataPool
else
  echo "JDBC pool could not be configured because of missing Variables DB_JDBC_IDLE_TIMEOUT or DB_JDBC_MAXPOOLSIZE"
  exit -1
fi

set +e
${ASADMIN} delete-javamail-resource mail/MailSession
set -e

${ASADMIN} create-javamail-resource --mailhost ${MAIL_HOST} --mailuser ${EMAIL_SENDER_NAME} --fromaddress ${EMAIL_SENDER_ADDRESS} --auth ${SMTP_AUTH_ENABLED} --enabled ${EMAIL_NOTIFICATION_ENABLED} --property  "mail.smtp.port=${SMTP_PORT}:mail.smtp.auth=${SMTP_AUTH_ENABLED}" mail/MailSession

# Fix for https://github.com/sormas-foundation/SORMAS-Project/issues/1759
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
  ${ASADMIN} set-config-property --propertyName=payara.security.openid.clientSecret --propertyValue=${KEYCLOAK_SORMAS_UI_SECRET} --source=domain
  ${ASADMIN} set-config-property --propertyName=payara.security.openid.scope --propertyValue=openid --source=domain
  ${ASADMIN} set-config-property --propertyName=payara.security.openid.providerURI --propertyValue=https://${SORMAS_SERVER_URL}/keycloak/realms/SORMAS --source=domain
  ${ASADMIN} set-config-property --propertyName=payara.security.openid.provider.notify.logout --propertyValue=true --source=domain
  ${ASADMIN} set-config-property --propertyName=payara.security.openid.logout.redirectURI --propertyValue=https://${SORMAS_SERVER_URL}/sormas-ui
  ${ASADMIN} set-config-property --propertyName=sormas.rest.security.oidc.json --propertyValue="{\"realm\":\"SORMAS\",\"auth-server-url\":\"https://${SORMAS_SERVER_URL}/keycloak\",\"ssl-required\":\"external\",\"resource\":\"sormas-rest\",\"credentials\":{\"secret\":\"${KEYCLOAK_SORMAS_REST_SECRET}\"},\"confidential-port\":0,\"principal-attribute\":\"preferred_username\",\"enable-basic-auth\":true}" --source=domain
  ${ASADMIN} set-config-property --propertyName=sormas.backend.security.oidc.json --propertyValue="{\"realm\":\"SORMAS\",\"auth-server-url\":\"https://${SORMAS_SERVER_URL}/keycloak\",\"ssl-required\":\"external\",\"resource\":\"sormas-backend\",\"credentials\":{\"secret\":\"${KEYCLOAK_SORMAS_BACKEND_SECRET}\"},\"confidential-port\":0}" --source=domain
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
sed -i "/^map.tiles.url /d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^map.tiles.attribution/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^app.url/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^ui.url/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^namesimilaritythreshold/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^duplicatechecks.excludepersonsonlylinkedtoarchivedentries/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^map.usecountrycenter/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^feature.automaticcaseclassification/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^documentUploadSizeLimitMb/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^importFileSizeLimitMb/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^audit.logger.config/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^audit.source.site/d" ${DOMAIN_DIR}/sormas.properties
sed -i "/^allowed.file.extensions/d " ${DOMAIN_DIR}/sormas.properties

if [ ! -z "$CREATE_DEFAULT_ENTITIES" ] && [ ! "$CREATE_DEFAULT_ENTITIES" == "" ];then
  echo -e "\ncreateDefaultEntities=${CREATE_DEFAULT_ENTITIES}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$LOCALE" ] && [ ! "$LOCALE" == "" ];then
  echo -e "\ncountry.locale=${LOCALE}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$COUNTRY_NAME" ] && [ ! "$COUNTRY_NAME" == "" ];then
  echo -e "\ncountry.name=${COUNTRY_NAME}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$EPIDPREFIX" ] && [ ! "$EPIDPREFIX" == "" ];then
  echo -e "\ncountry.epidprefix=${EPIDPREFIX}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$SEPARATOR" ] && [ ! "$SEPARATOR" == "" ];then
  echo -e "\ncsv.separator=${SEPARATOR}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$EMAIL_SENDER_ADDRESS" ] && [ ! "$EMAIL_SENDER_ADDRESS" == "" ];then
  echo -e "\nemail.sender.address=${EMAIL_SENDER_ADDRESS}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$EMAIL_SENDER_NAME" ] && [ ! "$EMAIL_SENDER_NAME" == "" ];then
  echo -e "\nemail.sender.name=${EMAIL_SENDER_NAME}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$LATITUDE" ] && [ ! "$LATITUDE" == "" ];then
  echo -e "\ncountry.center.latitude=${LATITUDE}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$LONGITUDE" ] && [ ! "$LONGITUDE" == "" ];then
  echo -e "\ncountry.center.longitude=${LONGITUDE}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$MAP_ZOOM" ] && [ ! "$MAP_ZOOM" == "" ];then
  echo -e "\nmap.zoom=${MAP_ZOOM}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$MAP_TILES_URL" ] && [ "$MAP_TILES_URL" != "" ];then
  echo -e "\nmap.tiles.url=${MAP_TILES_URL}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$MAP_TILES_ATTRIBUTION" ] && [ "$MAP_TILES_ATTRIBUTION" != "" ];then
  echo -e "\nmap.tiles.attribution=${MAP_TILES_ATTRIBUTION}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$SORMAS_SERVER_URL" ] && [ ! "$SORMAS_SERVER_URL" == "" ] && [ ! -z "$SORMAS_VERSION" ] && [ ! "$SORMAS_VERSION" == "" ];then
  echo -e "\napp.url=https://${SORMAS_SERVER_URL}/downloads/release/sormas-${SORMAS_VERSION}-release.apk" >>${DOMAIN_DIR}/sormas.properties
fi
if [ -n "${UI_URL}" ]; then
  echo -e "\nui.url=https://${SORMAS_SERVER_URL}/sormas-ui/"
else
  echo -e "\nui.url=${UI_URL}"
fi
if [ ! -z "$NAMESIMILARITYTHRESHOLD" ] && [ "$NAMESIMILARITYTHRESHOLD" != "" ];then
  echo -e "\nnamesimilaritythreshold=${NAMESIMILARITYTHRESHOLD}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$DC_EXCLUDE_ARCHIVED_PERSON_ENTRIES" ] && [ "$DC_EXCLUDE_ARCHIVED_PERSON_ENTRIES" != "" ];then
  echo -e "\nduplicatechecks.excludepersonsonlylinkedtoarchivedentries=${DC_EXCLUDE_ARCHIVED_PERSON_ENTRIES}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$MAP_USECOUNTRYCENTER" ] && [ "$MAP_USECOUNTRYCENTER" != "" ];then
  echo -e "\nmap.usecountrycenter=${MAP_USECOUNTRYCENTER}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$FEATURE_AUTOMATICCASECLASSIFICATION" ] && [ "$FEATURE_AUTOMATICCASECLASSIFICATION" != "" ];then
  echo -e "\nfeature.automaticcaseclassification=${FEATURE_AUTOMATICCASECLASSIFICATION}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$DOCUMENTUPLOADSIZELIMITMB" ] && [ "$DOCUMENTUPLOADSIZELIMITMB" != "" ];then
  echo -e "\ndocumentUploadSizeLimitMb=${DOCUMENTUPLOADSIZELIMITMB}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$IMPORTFILESIZELIMITMB" ] && [ "$IMPORTFILESIZELIMITMB" != "" ];then
  echo -e "\nimportFileSizeLimitMb=${IMPORTFILESIZELIMITMB}" >>${DOMAIN_DIR}/sormas.properties
fi

if [ ! -z "$AUDIT_LOGGER_CONFIG" ] && [ "$AUDIT_LOGGER_CONFIG" != "" ];then
  echo -e "\naudit.logger.config=${AUDIT_LOGGER_CONFIG}" >>${DOMAIN_DIR}/sormas.properties
  echo -e "\naudit.source.site=${SORMAS_SERVER_URL}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$ALLOWED_FILE_EXTENSIONS" ] && [ "$ALLOWED_FILE_EXTENSIONS" != "" ];then
  echo -e "\nallowed.file.extensions=${ALLOWED_FILE_EXTENSIONS}" >>${DOMAIN_DIR}/sormas.properties
fi

#------------------GEOCODING
sed -i "/^geocodingServiceUrlTemplate/d " ${DOMAIN_DIR}/sormas.properties
sed -i "/^geocodingLongitudeJsonPath/d " ${DOMAIN_DIR}/sormas.properties
sed -i "/^geocodingLatitudeJsonPath/d " ${DOMAIN_DIR}/sormas.properties

if [ ! -z "$GEO_TEMPLATE" ] && [ "$GEO_TEMPLATE" != "" ];then
  echo -e "\ngeocodingServiceUrlTemplate=${GEO_TEMPLATE}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$GEO_LONG_TEMPLATE" ] && [ "$GEO_LONG_TEMPLATE" != "" ];then
  echo -e "geocodingLongitudeJsonPath=${GEO_LONG_TEMPLATE}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$GEO_LAT_TEMPLATE" ] && [ "$GEO_LAT_TEMPLATE" != "" ];then
  echo -e "geocodingLatitudeJsonPath=${GEO_LAT_TEMPLATE}" >>${DOMAIN_DIR}/sormas.properties
fi
if [ ! -z "$GEO_UUID" ] && [ "$GEO_UUID" != "" ];then
  sed -i "s/\${GEO_UUID}/${GEO_UUID}/" ${DOMAIN_DIR}/sormas.properties
fi

sed -i "s/\#rscript.executable=.*/rscript.executable=Rscript/" ${DOMAIN_DIR}/sormas.properties
sed -i "/devmode=/d " ${DOMAIN_DIR}/sormas.properties
if [ ! -z "$DEVMODE" ] && [ "$DEVMODE" != "" ];then
  echo -e "\ndevmode=${DEVMODE}" >> ${DOMAIN_DIR}/sormas.properties
fi

#------------------PIA CONFIG
if [ ! -z "$PIA_URL" ];then
  if [ ! -z "$PIA_URL" ] && [ "$PIA_URL" != "" ];then
    sed -i "s/\#interface.pia.url=.*/interface.pia.url=${PIA_URL}/" ${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$SJ_URL" ] && [ "$SJ_URL" != "" ];then
    echo -e "\ninterface.symptomjournal.url = ${SJ_URL}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$SJ_AUTH" ] && [ "$SJ_AUTH" != "" ];then
    echo "interface.symptomjournal.authurl = ${SJ_AUTH}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$SJ_CLIENTID" ] && [ "$SJ_CLIENTID" != "" ];then
    echo "interface.symptomjournal.clientid = ${SJ_CLIENTID}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$SJ_SECRET" ] && [ "$SJ_SECRET" != "" ];then
    echo "interface.symptomjournal.secret = ${SJ_SECRET}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$SJ_DEFAULT_USERNAME" ] && [ "$SJ_DEFAULT_USERNAME" != "" ];then
    echo "interface.symptomjournal.defaultuser.username = ${SJ_DEFAULT_USERNAME}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$SJ_DEFAULT_PASSWORD" ] && [ "$SJ_DEFAULT_PASSWORD" != "" ];then
    echo "interface.symptomjournal.defaultuser.password = ${SJ_DEFAULT_PASSWORD}" >>${DOMAIN_DIR}/sormas.properties
  fi
fi

#------------------CLIMEDO CONFIG
sed -i "/^interface\.patientdiary\.url/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.probandsurl/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.authurl/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.email/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.password/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.defaultuser\.username/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.defaultuser\.password/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^interface\.patientdiary\.tokenLifetime\.password/d" "${DOMAIN_DIR}/sormas.properties"

if [ ! -z "$PATIENTDIARY_ENABLED" ];then
  if [ ! -z "$PD_URL" ] && [ "$PD_URL" != "" ];then
    echo -e "\ninterface.patientdiary.url=${PD_URL}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$PD_PROBANDS_URL" ] && [ "$PD_PROBANDS_URL" != "" ];then
    echo -e "\ninterface.patientdiary.probandsurl=${PD_PROBANDS_URL}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$PD_AUTH_URL" ] && [ "$PD_AUTH_URL" != "" ];then
    echo -e "\ninterface.patientdiary.authurl=${PD_AUTH_URL}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$PD_EMAIL" ] && [ "$PD_EMAIL" != "" ];then
    echo -e "\ninterface.patientdiary.email=${PD_EMAIL}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$PD_PASSWORD" ] && [ "$PD_PASSWORD" != "" ];then
    echo -e "\ninterface.patientdiary.password=${PD_PASSWORD}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$PD_DEFAULT_USERNAME" ] && [ "$PD_DEFAULT_USERNAME" != "" ];then
    echo -e "\ninterface.patientdiary.defaultuser.username=${PD_DEFAULT_USERNAME}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$PD_DEFAULT_PASSWORD" ] && [ "$PD_DEFAULT_PASSWORD" != "" ];then
    echo -e "\ninterface.patientdiary.defaultuser.password=${PD_DEFAULT_PASSWORD}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$PD_ACCEPTPHONECONTACT" ] && ([ "$PD_ACCEPTPHONECONTACT" == "true" ] || [ "$PD_ACCEPTPHONECONTACT" == "True" ]);then
    echo -e "\ninterface.patientdiary.acceptPhoneContact=${PD_ACCEPTPHONECONTACT}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$PD_FRONTENDAUTHURL" ] && [ "$PD_FRONTENDAUTHURL" != "" ];then
    echo -e "\ninterface.patientdiary.frontendAuthurl=${PD_FRONTENDAUTHURL}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$PD_TOKENLIFETIME" ] && [ "$PD_TOKENLIFETIME" != "" ];then
    echo -e "\ninterface.patientdiary.tokenLifetime=${PD_TOKENLIFETIME}" >>${DOMAIN_DIR}/sormas.properties
  fi
fi

#------------------BRANDING CONFIG
if [ ! -z "$CUSTOMBRANDING_ENABLED" ];then
  if [ "$CUSTOMBRANDING_ENABLED" != "" ];then
    sed -i "s/\#custombranding=false/custombranding=${CUSTOMBRANDING_ENABLED}/" ${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$CUSTOMBRANDING_NAME" ] && [ "$CUSTOMBRANDING_NAME" != "" ];then
    sed -i "s/\#custombranding.name=.*/custombranding.name=${CUSTOMBRANDING_NAME}/" ${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$CUSTOMBRANDING_LOGO_PATH" ] && [ "$CUSTOMBRANDING_LOGO_PATH" != "" ];then
    echo -e "\ncustombranding.logo.path=${CUSTOMBRANDING_LOGO_PATH}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$CUSTOMBRANDING_USE_LOGINSIDEBAR" ] && [ "$CUSTOMBRANDING_USE_LOGINSIDEBAR" != "" ];then
    echo -e "\ncustombranding.useloginsidebar=${CUSTOMBRANDING_USE_LOGINSIDEBAR}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$CUSTOMBRANDING_LOGINBACKGROUND_PATH" ] && [ "$CUSTOMBRANDING_LOGINBACKGROUND_PATH" != "" ];then
    echo -e "\ncustombranding.loginbackground.path=${CUSTOMBRANDING_LOGINBACKGROUND_PATH}" >>${DOMAIN_DIR}/sormas.properties
  fi
fi

### SORMAS CENTRAL ###
echo "Sormas Central"
if [ ! -z  "$SORMAS_CENTRAL_ENABLED" ]; then
  echo "Sormas Central enabled"
  sed -i -E "s/#?central.oidc.url=.*/central.oidc.url=${CENTRAL_OIDC_URL}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?central.etcd.host=.*/central.etcd.host=${CENTRAL_ETCD_HOST}/" "${PROPERTIES_FILE}"
  sed -i -E "s~#?central.etcd.caPath=.*~central.etcd.caPath=${CENTRAL_ETCD_CA_PATH}~" "${PROPERTIES_FILE}"
  sed -i -E "s/#?central.etcd.clientName=.*/central.etcd.clientName=${CENTRAL_ETCD_CLIENTNAME}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?central.etcd.clientPassword=.*/central.etcd.clientPassword=${CENTRAL_ETCD_CLIENTPASSWORD}/" "${PROPERTIES_FILE}"
  sed -i -E "s/^.*central.location.sync=.*/central.location.sync=${CENTRAL_LOCATION_SYNC}/" "${PROPERTIES_FILE}"
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

  sed -i -E "s/#?sormas2sormas.etcd.keyPrefix=.*/sormas2sormas.etcd.keyPrefix=${SORMAS2SORMAS_ETCD_KEYPREFIX}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.retainCaseExternalToken=.*/sormas2sormas.retainCaseExternalToken=${SORMAS2SORMAS_RETAINCASEEXTERNALTOKEN}/" "${PROPERTIES_FILE}"

  sed -i -E "s/#?sormas2sormas.ignoreProperty.additionalDetails=.*/sormas2sormas.ignoreProperty.additionalDetails=${SORMAS2SORMAS_IGNOREPROPERTY_ADDITIONALDETAILS}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.ignoreProperty.externalId=.*/sormas2sormas.ignoreProperty.externalId=${SORMAS2SORMAS_IGNOREPROPERTY_EXTERNALID}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.ignoreProperty.externalToken=.*/sormas2sormas.ignoreProperty.externalToken=${SORMAS2SORMAS_IGNOREPROPERTY_EXTERNALTOKEN}/" "${PROPERTIES_FILE}"
  sed -i -E "s/#?sormas2sormas.ignoreProperty.internalToken=.*/sormas2sormas.ignoreProperty.internalToken=${SORMAS2SORMAS_IGNOREPROPERTY_INTERNALTOKEN}/" "${PROPERTIES_FILE}"
  if [ ! -z "$SORMAS2SORMAS_DISTRICT_EXTERNALID" ] && [ "$SORMAS2SORMAS_DISTRICT_EXTERNALID" != "" ];then
    sed -i -E "s/#?sormas2sormas.districtExternalId=.*/sormas2sormas.districtExternalId=${SORMAS2SORMAS_DISTRICT_EXTERNALID}/" "${PROPERTIES_FILE}"
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
sed -i "/^survnet\.versionEndpoint/d" "${DOMAIN_DIR}/sormas.properties"
sed -i "/^sormas\.district-external-id/d" "${DOMAIN_DIR}/sormas.properties"

if [ ! -z "$SURVNET_ENABLED" ];then
  if [ ! -z "$SURVNET_URL" ] && [ "$SURVNET_URL" != "" ];then
    echo -e "\nsurvnet.url=${SURVNET_URL}" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$SURVNET_VERSION_ENDPOINT" ] && [ ! "$SURVNET_VERSION_ENDPOINT" == "" ];then
    echo -e "\nsurvnet.versionEndpoint=${SURVNET_VERSION_ENDPOINT}" >>${DOMAIN_DIR}/sormas.properties
  fi
fi
#------------------SORMAS-Stats CONFIG
sed -i "/^sormasStats\.url/d" "${DOMAIN_DIR}/sormas.properties"
if [ ! -z "$SORMAS_STATS_ENABLED" ] && [ "$SORMAS_STATS_ENABLED" == "true" ] && [ ! -z "$SORMAS_STATS_URL" ] && [ ! "$SORMAS_STATS_URL" == "" ];then
  echo -e "\nsormasStats.url=${SORMAS_STATS_URL}" >>${DOMAIN_DIR}/sormas.properties
fi

#------------------DEMIS CONFIG
if [ ! -z "$DEMIS_ENABLED" ] ;then
  set +e
  cp -a /tmp/${DOMAIN_NAME}/config/demis/. ${DOMAIN_DIR}/config/
  set -e
  # new Facade for SORMAS >= 1.86.0
  if [ ! -z "$DEMIS_VERSION" ] && [ "$DEMIS_VERSION" != "" ];then
    echo -e "\ninterface.externalMessageAdapter.jndiName=java:global/sormas-demis-adapter-${DEMIS_VERSION}/DemisMessageFacade" >>${DOMAIN_DIR}/sormas.properties
  fi
  if [ ! -z "$DEBUGINFO_ENABLED" ] && [ "$DEBUGINFO_ENABLED" != "" ];then
    echo -e "\ndebuginfo.enabled=${DEBUGINFO_ENABLED}" >${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$FHIR_BASEPATH" ] && [ "$FHIR_BASEPATH" != "" ];then
    echo -e "\nfhir.basepath=${FHIR_BASEPATH}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$IDP_TOKENENDPOINT" ] && [ "$IDP_TOKENENDPOINT" != "" ];then
    echo -e "\nidp.tokenendpoint=${IDP_TOKENENDPOINT}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$IDP_LAB_TOKENENDPOINT" ] && [ "$IDP_LAB_TOKENENDPOINT" != "" ];then
    echo -e "\nidp.lab.tokenendpoint=${IDP_LAB_TOKENENDPOINT}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  
  if [ ! -z "$IDP_OEGD_PROXY" ] && [ "$IDP_OEGD_PROXY" != "" ];then
    echo -e "\nidp.oegd.proxy=${IDP_OEGD_PROXY}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$IDP_OEGD_CLIENTID" ] && [ "$IDP_OEGD_CLIENTID" != "" ];then
    echo -e "\nidp.oegd.clientid=${IDP_OEGD_CLIENTID}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$IDP_OEGD_SECRET" ] && [ "$IDP_OEGD_SECRET" != "" ];then
    echo -e "\nidp.oegd.secret=${IDP_OEGD_SECRET}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$IDP_OEGD_USERNAME" ] && [ "$IDP_OEGD_USERNAME" != "" ];then
    echo -e "\nidp.oegd.username=${IDP_OEGD_USERNAME}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$IDP_OEGD_TRUSTSTORE" ] && [ "$IDP_OEGD_TRUSTSTORE" != "" ];then
    echo -e "\nidp.oegd.truststore=${IDP_OEGD_TRUSTSTORE}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$IDP_OEGD_TRUSTSTOREPASSWORD" ] && [ "$IDP_OEGD_TRUSTSTOREPASSWORD" != "" ];then
    echo -e "\nidp.oegd.truststorepassword=${IDP_OEGD_TRUSTSTOREPASSWORD}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$IDP_OEGD_AUTHCERTKEYSTORE" ] && [ "$IDP_OEGD_AUTHCERTKEYSTORE" != "" ];then
    echo -e "\nidp.oegd.authcertkeystore=${IDP_OEGD_AUTHCERTKEYSTORE}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$IDP_OEGD_AUTHCERTPASSWORD" ] && [ "$IDP_OEGD_AUTHCERTPASSWORD" != "" ];then
    echo -e "\nidp.oegd.authcertpassword=${IDP_OEGD_AUTHCERTPASSWORD}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$IDP_OEGD_AUTHCERTALIAS" ] && [ "$IDP_OEGD_AUTHCERTALIAS" != "" ];then
    echo -e "\nidp.oegd.authcertalias=${IDP_OEGD_AUTHCERTALIAS}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  
  if [ ! -z "$IDP_OEGD_OUTDATED_AUTHCERTKEYSTORE" ] && [ "$IDP_OEGD_OUTDATED_AUTHCERTKEYSTORE" != "" ];then
    echo -e "\nidp.oegd.outdated.authcertkeystore=${IDP_OEGD_OUTDATED_AUTHCERTKEYSTORE}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$IDP_OEGD_OUTDATED_AUTHCERTPASSWORD" ] && [ "$IDP_OEGD_OUTDATED_AUTHCERTPASSWORD" != "" ];then
    echo -e "\nidp.oegd.outdated.authcertpassword=${IDP_OEGD_OUTDATED_AUTHCERTPASSWORD}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  
  if [ ! -z "$CONNECT_TIMEOUT_MS" ] && [ "$CONNECT_TIMEOUT_MS" != "" ];then
    echo -e "\nconnect.timeout.ms=${CONNECT_TIMEOUT_MS}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$CONNECTION_REQUEST_TIMEOUT_MS" ] && [ "$CONNECTION_REQUEST_TIMEOUT_MS" != "" ];then
    echo -e "\nconnection.request.timeout.ms=${CONNECTION_REQUEST_TIMEOUT_MS}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi
  if [ ! -z "$SOCKET_TIMEOUT_MS" ] && [ "$SOCKET_TIMEOUT_MS" != "" ];then
    echo -e "\nsocket.timeout.ms=${SOCKET_TIMEOUT_MS}" >>${DOMAIN_DIR}/config/demis-adapter.properties
  fi

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
  for file in $(ls /tmp/certs/*.crt); do
      base_name=$(basename $file .crt)
      keytool -storepass ${CACERTS_PASS} -importcert -trustcacerts -destkeystore ${DOMAIN_DIR}/config/cacerts.jks -file /tmp/certs/${base_name}.crt -alias ${base_name} -noprompt
      openssl pkcs12 -export -in /tmp/certs/${base_name}.crt -inkey /tmp/certs/${base_name}.key -out ${base_name}.p12 -name ${base_name} -password pass:${KEYSTORE_PASS}
      keytool -storepass ${KEYSTORE_PASS} -importkeystore -destkeystore ${DOMAIN_DIR}/config/keystore.jks -srckeystore ${base_name}.p12 -srcstoretype PKCS12 -srcstorepass changeit -alias ${base_name} -noprompt
  done
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
