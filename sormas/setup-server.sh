#!/bin/bash
# entering exit immediately mode
set -e

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
SORMAS2SORMAS_DIR=${ROOT_PREFIX}/opt/sormas/sormas2sormas
CENTRAL_DIR=${ROOT_PREFIX}/opt/sormas/central

PORT_BASE=6000
PORT_ADMIN=6048
DOMAIN_DIR=${DOMAINS_HOME}/${DOMAIN_NAME}
LOG_FILE_PATH=${DOMAIN_DIR}/logs
LOG_FILE_NAME=server_update_`date +"%Y-%m-%d_%H-%M-%S"`.log

mkdir -p ${PAYARA_HOME}
mkdir -p ${DOMAINS_HOME}
mkdir -p ${TEMP_DIR}
mkdir -p ${DOCUMENTS_DIR}
mkdir -p ${GENERATED_DIR}
mkdir -p ${CUSTOM_DIR}
mkdir -p ${DEPLOY_PATH}
mkdir -p ${DOWNLOADS_PATH}
mkdir -p ${SORMAS2SORMAS_DIR}
mkdir -p ${CENTRAL_DIR}

  pushd ${DEPLOY_PATH}
  wget ${SORMAS_URL}v${SORMAS_VERSION}/sormas_${SORMAS_VERSION}.zip -O ${DOMAIN_NAME}.zip
  unzip ${DOMAIN_NAME}.zip
  rm ${DOMAIN_NAME}.zip
  popd



# Setting ASADMIN_CALL and creating domain
echo "Creating domain for Payara..."
${PAYARA_HOME}/bin/asadmin create-domain --domaindir ${DOMAINS_HOME} --portbase ${PORT_BASE} --nopassword "${DOMAIN_NAME}"
ASADMIN="${PAYARA_HOME}/bin/asadmin --port ${PORT_ADMIN}"

chown -R ${USER_NAME}:${USER_NAME} ${PAYARA_HOME}

${PAYARA_HOME}/bin/asadmin start-domain --domaindir ${DOMAINS_HOME} ${DOMAIN_NAME}

echo "Configuring domain and database connection..."

# General domain settings
${ASADMIN} delete-jvm-options '-client'
${ASADMIN} delete-jvm-options -Xmx512m
${ASADMIN} create-jvm-options -Xmx4096m

${ASADMIN} create-jvm-options '-XX\:+IgnoreUnrecognizedVMOptions'
${ASADMIN} create-system-properties --target server-config fish.payara.classloading.delegate=false
${ASADMIN} get configs.config.server-config.ejb-container.max-pool-size
${ASADMIN} set configs.config.server-config.ejb-container.max-pool-size=128
${ASADMIN} set configs.config.server-config.thread-pools.thread-pool.http-thread-pool.max-thread-pool-size=50

# Set protocol in redirects according to X-Forwarded-Proto (set by reverse proxy)
${ASADMIN} set server.network-config.protocols.protocol.http-listener-1.http.scheme-mapping=X-Forwarded-Proto

# JDBC pool
echo "Configuring JDBC pool"
${ASADMIN} create-jdbc-connection-pool --restype javax.sql.ConnectionPoolDataSource --datasourceclassname org.postgresql.ds.PGConnectionPoolDataSource --isconnectvalidatereq true --validationmethod custom-validation --validationclassname org.glassfish.api.jdbc.validation.PostgresConnectionValidation --maxpoolsize ${DB_JDBC_MAXPOOLSIZE} --property "portNumber=5432:databaseName=${DB_NAME}:serverName=${DB_HOST}:user=${SORMAS_POSTGRES_USER}:password=${SORMAS_POSTGRES_PASSWORD}" ${DOMAIN_NAME}DataPool
${ASADMIN} create-jdbc-resource --connectionpoolid ${DOMAIN_NAME}DataPool jdbc/${DOMAIN_NAME}DataPool

# Pool for audit log
echo "Configuring audit log"
${ASADMIN} create-jdbc-connection-pool --restype javax.sql.XADataSource --datasourceclassname org.postgresql.xa.PGXADataSource --isconnectvalidatereq true --validationmethod custom-validation --validationclassname org.glassfish.api.jdbc.validation.PostgresConnectionValidation --maxpoolsize ${DB_JDBC_MAXPOOLSIZE} --property "portNumber=5432:databaseName=${DB_NAME_AUDIT}:serverName=${DB_HOST}:user=${SORMAS_POSTGRES_USER}:password=${SORMAS_POSTGRES_PASSWORD}" ${DOMAIN_NAME}AuditlogPool
${ASADMIN} create-jdbc-resource --connectionpoolid ${DOMAIN_NAME}AuditlogPool jdbc/AuditlogPool

${ASADMIN} create-javamail-resource --mailhost localhost --mailuser user --fromaddress ${MAIL_FROM} mail/MailSession

${ASADMIN} create-custom-resource --restype java.util.Properties --factoryclass org.glassfish.resources.custom.factory.PropertiesFactory --property "org.glassfish.resources.custom.factory.PropertiesFactory.fileName=\${com.sun.aas.instanceRoot}/sormas.properties" sormas/Properties

echo "Deploy artifacts"
cp ${DEPLOY_PATH}/deploy/sormas.properties ${DOMAIN_DIR}
cp ${DEPLOY_PATH}/deploy/start-payara-sormas.sh ${DOMAIN_DIR}
cp ${DEPLOY_PATH}/deploy/stop-payara-sormas.sh ${DOMAIN_DIR}
cp ${DEPLOY_PATH}/deploy/logback.xml ${DOMAIN_DIR}/config/
cp ${DEPLOY_PATH}/deploy/loginsidebar.html ${CUSTOM_DIR}
cp ${DEPLOY_PATH}/deploy/logindetails.html ${CUSTOM_DIR}
cp ${DEPLOY_PATH}/deploy/loginmain.html ${CUSTOM_DIR}

chown -R ${USER_NAME}:${USER_NAME} ${DOMAIN_DIR}

# Logging
# Disable payara log rotation.
# When server.log is rotated, we loose logging on console ($LOG_FILE_PATH/server.log is linked to stdout)
echo "Configuring logging..."
${ASADMIN} create-jvm-options -Dlogback.configurationFile=\${com.sun.aas.instanceRoot}/config/logback.xml
${ASADMIN} set-log-attributes com.sun.enterprise.server.logging.GFFileHandler.rotationLimitInBytes=0

#${ASADMIN} set-log-levels org.wamblee.glassfish.auth.HexEncoder=SEVERE
#${ASADMIN} set-log-levels javax.enterprise.system.util=SEVERE


# # Make the payara listen to localhost only
# echo "Configuring security settings..."
# ${ASADMIN} set configs.config.server-config.http-service.virtual-server.server.network-listeners=http-listener-1
# ${ASADMIN} delete-network-listener --target=server-config http-listener-2
# ${ASADMIN} set configs.config.server-config.network-config.network-listeners.network-listener.admin-listener.address=127.0.0.1
# ${ASADMIN} set configs.config.server-config.network-config.network-listeners.network-listener.http-listener-1.address=127.0.0.1
# ${ASADMIN} set configs.config.server-config.iiop-service.iiop-listener.orb-listener-1.address=127.0.0.1
# ${ASADMIN} set configs.config.server-config.iiop-service.iiop-listener.SSL.address=127.0.0.1
# ${ASADMIN} set configs.config.server-config.iiop-service.iiop-listener.SSL_MUTUALAUTH.address=127.0.0.1
# ${ASADMIN} set configs.config.server-config.jms-service.jms-host.default_JMS_host.host=127.0.0.1
# ${ASADMIN} set configs.config.server-config.admin-service.jmx-connector.system.address=127.0.0.1
# ${ASADMIN} set-hazelcast-configuration --enabled=false

#$GLASSFISH_PATH/bin/asadmin start-domain --domaindir $DOMAIN_PATH $DOMAIN_NAME > $LOG_PATH/$LOG_FILE_NAME

#sleep 10

#echo "Copying apk files..."
#cp ${DEPLOY_PATH}/deploy/android/release/*.apk ${DOWNLOADS_PATH}

echo "Copying server libs..."

cp ${DEPLOY_PATH}/deploy/serverlibs/* ${DOMAIN_DIR}/lib/

echo "Copying apps..."

mkdir -p ${DOMAIN_DIR}/deployments
cp ${DEPLOY_PATH}/deploy/apps/*.ear ${DOMAIN_DIR}/deployments/
cp ${DEPLOY_PATH}/deploy/apps/*.war ${DOMAIN_DIR}/deployments/
cp ${DEPLOY_PATH}/deploy/s2s-import-to-truststore.sh /opt/sormas/sormas2sormas

#Der String "300" tritt ausschließlich an Stellen auf an denen die (txn-)Timeouts definiert werden. Diese werden auf "0" gesetzt um die Timeouts zu deaktivieren
echo "Configure payara timeouts ..."
sed -i 's/"300"/"0"/g' ${DOMAIN_DIR}/config/domain.xml
# Remove additional application.* log files
sed -i -E "/<appender-ref ref=\"FILE_([A-Z])+\"\ \/>/d" ${DOMAIN_DIR}/config/logback.xml
# echo "Set logging fo documents to WARNING level"
# sed -i '/<root level="debug">/i\ \ \ \ <logger name="fr.opensagres.xdocreport" level="WARN" />' ${DOMAIN_DIR}/config/logback.xml

# Patching logback.xml - there is an assumption that searched phrases exist - if not - should exit
echo "Patching logback.xml configuration"
# entering debug mode to get know of failing line in case of error-exit
set -x
grep '^[[:blank:]]*<smtpHost>localhost</smtpHost>[[:blank:]]*$' ${DOMAIN_DIR}/config/logback.xml
grep '<!-- <appender-ref ref="EMAIL_ERROR" /> -->' ${DOMAIN_DIR}/config/logback.xml
grep '<subject>SORMAS: %logger{20} - %m</subject>' ${DOMAIN_DIR}/config/logback.xml
sed -i 's|<subject>SORMAS: %logger{20} - %m</subject>|<!-- <subject>SORMAS: %logger{20} - %m</subject> -->|' ${DOMAIN_DIR}/config/logback.xml
sed -i 's|<smtpHost>localhost</smtpHost>|\t<smtpHost>MAIL_HOST</smtpHost>\n\t\t<smtpPort>SMTP_PORT</smtpPort>\n\t\t<username>SMTP_USER</username>\n\t\t<password>SMTP_PASSWORD</password>\n\t\t<STARTTLS>SMTP_STARTTLS</STARTTLS>\n\t\t<SSL>SMTP_SSL</SSL>\n\t\t<asynchronousSending>SMTP_ASYNC_SENDING</asynchronousSending>\n\t\t<to>LOG_RECIPIENT_ADDRESS</to>\n\t\t<from>LOG_SENDER_ADDRESS</from>\n\t\t<subject>LOG_SUBJECT</subject>|' ${DOMAIN_DIR}/config/logback.xml
set +x
# switch off debug mode

${PAYARA_HOME}/bin/asadmin stop-domain --domaindir ${DOMAINS_HOME}

rm -rf ${DOMAIN_DIR}/osgi-cache/*
rm -rf ${DOMAIN_DIR}/applications/*
rm -rf ${DOMAIN_DIR}/generated/*
rm -rf ${DOMAIN_DIR}/logs/*
rm -rf /opt/payara5/mq/javadoc
rm -rf /opt/payara5/mq/examples
rm -rf ${DEPLOY_PATH}

echo "Server setup completed."
