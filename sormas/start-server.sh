#!/bin/bash

function check_db() {
  psql -h ${DB_HOST} -U ${SORMAS_POSTGRES_USER} ${DB_NAME} --no-align --tuples-only --quiet --command="SELECT count(*) FROM pg_database WHERE datname='${DB_NAME}';" 2>/dev/null || echo "0"
}

function check_java() {
  ps -ef | grep /usr/lib/jvm/zulu-8-amd64/bin/java | grep -v grep | wc -l
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

${PAYARA_HOME}/bin/asadmin start-domain --domaindir ${DOMAINS_HOME} ${DOMAIN_NAME}

echo "Configuring domain and database connection..."

# JVM settings
${ASADMIN} delete-jvm-options -Xmx4096m
${ASADMIN} create-jvm-options -Xmx${JVM_MAX}

# JDBC pool
delete_jdbc_connection_pool "jdbc/${DOMAIN_NAME}DataPool" "${DOMAIN_NAME}DataPool"
${ASADMIN} create-jdbc-connection-pool --restype javax.sql.ConnectionPoolDataSource --datasourceclassname org.postgresql.ds.PGConnectionPoolDataSource --isconnectvalidatereq true --validationmethod custom-validation --validationclassname org.glassfish.api.jdbc.validation.PostgresConnectionValidation --property "portNumber=5432:databaseName=${DB_NAME}:serverName=${DB_HOST}:user=${SORMAS_POSTGRES_USER}:password=${SORMAS_POSTGRES_PASSWORD}" ${DOMAIN_NAME}DataPool
${ASADMIN} create-jdbc-resource --connectionpoolid ${DOMAIN_NAME}DataPool jdbc/${DOMAIN_NAME}DataPool

# Pool for audit log
delete_jdbc_connection_pool "jdbc/AuditlogPool" "${DOMAIN_NAME}AuditlogPool"
${ASADMIN} create-jdbc-connection-pool --restype javax.sql.XADataSource --datasourceclassname org.postgresql.xa.PGXADataSource --isconnectvalidatereq true --validationmethod custom-validation --validationclassname org.glassfish.api.jdbc.validation.PostgresConnectionValidation --property "portNumber=5432:databaseName=${DB_NAME_AUDIT}:serverName=${DB_HOST}:user=${SORMAS_POSTGRES_USER}:password=${SORMAS_POSTGRES_PASSWORD}" ${DOMAIN_NAME}AuditlogPool
${ASADMIN} create-jdbc-resource --connectionpoolid ${DOMAIN_NAME}AuditlogPool jdbc/AuditlogPool

${ASADMIN} delete-javamail-resource mail/MailSession
${ASADMIN} create-javamail-resource --mailhost ${MAIL_HOST} --mailuser "sormas" --fromaddress ${MAIL_FROM} mail/MailSession

# Fix for https://github.com/hzi-braunschweig/SORMAS-Project/issues/1759
${ASADMIN} set configs.config.server-config.thread-pools.thread-pool.http-thread-pool.max-thread-pool-size=500
# set FQDN for sormas domain
${ASADMIN} set configs.config.server-config.http-service.virtual-server.server.hosts=${SORMAS_SERVER_URL}

${PAYARA_HOME}/bin/asadmin stop-domain --domaindir ${DOMAINS_HOME}
chown -R ${USER_NAME}:${USER_NAME} ${DOMAIN_DIR}

#Edit properties

sed -i "s/country.locale=.*/country.locale=${LOCALE}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/country.epidprefix=.*/country.epidprefix=${EPIDPREFIX}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/#csv.separator=.*/csv.separator=/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/csv.separator=.*/csv.separator=${SEPARATOR}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/#email.sender.address=.*/email.sender.address=/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/email.sender.address=.*/email.sender.address=${EMAIL_SENDER_ADDRESS}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/#email.sender.name=.*/email.sender.name=/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/email.sender.name=.*/email.sender.name=${EMAIL_SENDER_NAME}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/country.center.latitude=.*/country.center.latitude=${LATITUDE}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/country.center.longitude=.*/country.center.longitude=${LONGITUDE}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/map.zoom=.*/map.zoom=${map_zoom}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s;app.url=.*;app.url=https://${SORMAS_SERVER_URL}/downloads/release/sormas-${SORMAS_VERSION}-release.apk;" ${DOMAIN_DIR}/sormas.properties
sed -i "s/\#geocodingOsgtsEndpoint=.*/geocodingOsgtsEndpoint=https:\/\/sg.geodatenzentrum.de\/gdz_geokodierung_bund__${GEO_UUID}/" ${DOMAIN_DIR}/sormas.properties
sed -i "s/\#rscript.executable=.*/rscript.executable=Rscript/" ${DOMAIN_DIR}/sormas.properties

Rscript -e 'library(epicontacts)'
Rscript -e 'library(RPostgreSQL)'
Rscript -e 'library(visNetwork)'
Rscript -e 'library(dplyr)'

# put deployments into place
for APP in $(ls ${DOMAIN_DIR}/deployments/*.ear 2>/dev/null);do
  mv ${APP} ${DOMAIN_DIR}/autodeploy
done
sleep 5
for APP in $(ls ${DOMAIN_DIR}/deployments/*.war 2>/dev/null);do
  mv ${APP} ${DOMAIN_DIR}/autodeploy
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

echo "Server setup completed."

${PAYARA_HOME}/bin/asadmin start-domain --domaindir ${DOMAINS_HOME} ${DOMAIN_NAME}
tail -f $LOG_FILE_PATH/server.log
