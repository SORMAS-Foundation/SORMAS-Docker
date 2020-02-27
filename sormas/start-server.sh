LINUX=true

ROOT_PREFIX=
# make sure to update payara-sormas script when changing the user name
USER_NAME=payara
DOWNLOAD_DIR=${ROOT_PREFIX}/var/www/sormas/downloads


TEMP_DIR=${ROOT_PREFIX}/opt/sormas/temp
GENERATED_DIR=${ROOT_PREFIX}/opt/sormas/generated
CUSTOM_DIR=${ROOT_PREFIX}/opt/sormas/custom
PAYARA_HOME=${ROOT_PREFIX}/opt/payara5
DOMAINS_HOME=${ROOT_PREFIX}/opt/domains

DOMAIN_NAME=sormas
PORT_BASE=6000
PORT_ADMIN=6048
DOMAIN_DIR=${DOMAINS_HOME}/${DOMAIN_NAME}





# Setting ASADMIN_CALL and creating domain
echo "Creating domain for Payara..."
${PAYARA_HOME}/bin/asadmin create-domain --domaindir ${DOMAINS_HOME} --portbase ${PORT_BASE} --nopassword ${DOMAIN_NAME}
ASADMIN="${PAYARA_HOME}/bin/asadmin --port ${PORT_ADMIN}"

if [ ${LINUX} = true ]; then
	chown -R ${USER_NAME}:${USER_NAME} ${PAYARA_HOME}
fi

${PAYARA_HOME}/bin/asadmin start-domain --domaindir ${DOMAINS_HOME} ${DOMAIN_NAME}

# Set up the database
echo "Starting database setup..."

cat > setup.sql <<-EOF
CREATE USER $SORMAS_POSTGRES_USER WITH PASSWORD '$SORMAS_POSTGRES_PASSWORD' CREATEDB;
CREATE DATABASE $DB_NAME WITH OWNER = '$SORMAS_POSTGRES_USER' ENCODING = 'UTF8';
CREATE DATABASE $DB_NAME_AUDIT WITH OWNER = '$SORMAS_POSTGRES_USER' ENCODING = 'UTF8';
\c $DB_NAME
CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;
ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO $SORMAS_POSTGRES_USER;
CREATE EXTENSION temporal_tables;
CREATE EXTENSION pg_trgm;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO $SORMAS_POSTGRES_USER;
\c $DB_NAME_AUDIT
CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO $SORMAS_POSTGRES_USER;
ALTER TABLE IF EXISTS schema_version OWNER TO $SORMAS_POSTGRES_USER;
EOF

	/usr/bin/psql -h postgres -p 5432 -U postgres -f setup.sql


rm setup.sql

echo "---"
read -p "Database setup completed. Please check the output for any error. Press [Enter] to continue or [Strg+C] to cancel."



echo "Configuring domain and database..."

# General domain settings
${ASADMIN} delete-jvm-options -Xmx512m
${ASADMIN} create-jvm-options -Xmx4096m

# JDBC pool
${ASADMIN} create-jdbc-connection-pool --restype javax.sql.ConnectionPoolDataSource --datasourceclassname org.postgresql.ds.PGConnectionPoolDataSource --isconnectvalidatereq true --validationmethod custom-validation --validationclassname org.glassfish.api.jdbc.validation.PostgresConnectionValidation --property "portNumber=${DB_PORT}:databaseName=${DB_NAME}:serverName=localhost:user=${SORMAS_POSTGRES_USER}:password=${SORMAS_POSTGRES_PASSWORD}" ${DOMAIN_NAME}DataPool
${ASADMIN} create-jdbc-resource --connectionpoolid ${DOMAIN_NAME}DataPool jdbc/${DOMAIN_NAME}DataPool

# Pool for audit log
${ASADMIN} create-jdbc-connection-pool --restype javax.sql.XADataSource --datasourceclassname org.postgresql.xa.PGXADataSource --isconnectvalidatereq true --validationmethod custom-validation --validationclassname org.glassfish.api.jdbc.validation.PostgresConnectionValidation --property "portNumber=${DB_PORT}:databaseName=${DB_NAME_AUDIT}:serverName=localhost:user=${SORMAS_POSTGRES_USER}:password=${SORMAS_POSTGRES_PASSWORD}" ${DOMAIN_NAME}AuditlogPool
${ASADMIN} create-jdbc-resource --connectionpoolid ${DOMAIN_NAME}AuditlogPool jdbc/AuditlogPool

${ASADMIN} create-javamail-resource --mailhost localhost --mailuser user --fromaddress ${MAIL_FROM} mail/MailSession

${ASADMIN} create-custom-resource --restype java.util.Properties --factoryclass org.glassfish.resources.custom.factory.PropertiesFactory --property "org.glassfish.resources.custom.factory.PropertiesFactory.fileName=\${com.sun.aas.instanceRoot}/sormas.properties" sormas/Properties

cp sormas.properties ${DOMAIN_DIR}
cp start-payara-sormas.sh ${DOMAIN_DIR}
cp stop-payara-sormas.sh ${DOMAIN_DIR}
cp logback.xml ${DOMAIN_DIR}/config/
if [ ${DEV_SYSTEM} = true ] && [ ${LINUX} != true ]; then
	# Fixes outdated certificate - don't do this on linux systems!
	cp cacerts.txt ${DOMAIN_DIR}/config/cacerts.jks
fi
cp loginsidebar.html ${CUSTOM_DIR}
cp logindetails.html ${CUSTOM_DIR}
if [ ${DEMO_SYSTEM} = true ]; then
	cp demologinmain.html ${CUSTOM_DIR}/loginmain.html
else
	cp loginmain.html ${CUSTOM_DIR}
fi


if [ ${LINUX} = true ]; then
	cp payara-sormas /etc/init.d
	chmod 755 /etc/init.d/payara-sormas
	update-rc.d payara-sormas defaults

	chown -R ${USER_NAME}:${USER_NAME} ${DOMAIN_DIR}
fi

read -p "--- Press [Enter] to continue..."

# Logging
echo "Configuring logging..."
${ASADMIN} create-jvm-options -Dlogback.configurationFile=\${com.sun.aas.instanceRoot}/config/logback.xml
${ASADMIN} set-log-attributes com.sun.enterprise.server.logging.GFFileHandler.maxHistoryFiles=14
${ASADMIN} set-log-attributes com.sun.enterprise.server.logging.GFFileHandler.rotationLimitInBytes=0
${ASADMIN} set-log-attributes com.sun.enterprise.server.logging.GFFileHandler.rotationOnDateChange=true
#${ASADMIN} set-log-levels org.wamblee.glassfish.auth.HexEncoder=SEVERE
#${ASADMIN} set-log-levels javax.enterprise.system.util=SEVERE


	# Make the payara listen to localhost only
	echo "Configuring security settings..."
	${ASADMIN} set configs.config.server-config.http-service.virtual-server.server.network-listeners=http-listener-1
	${ASADMIN} delete-network-listener --target=server-config http-listener-2
	${ASADMIN} set configs.config.server-config.network-config.network-listeners.network-listener.admin-listener.address=127.0.0.1
	${ASADMIN} set configs.config.server-config.network-config.network-listeners.network-listener.http-listener-1.address=127.0.0.1
	${ASADMIN} set configs.config.server-config.iiop-service.iiop-listener.orb-listener-1.address=127.0.0.1
	${ASADMIN} set configs.config.server-config.iiop-service.iiop-listener.SSL.address=127.0.0.1
	${ASADMIN} set configs.config.server-config.iiop-service.iiop-listener.SSL_MUTUALAUTH.address=127.0.0.1
	${ASADMIN} set configs.config.server-config.jms-service.jms-host.default_JMS_host.host=127.0.0.1
	${ASADMIN} set configs.config.server-config.admin-service.jmx-connector.system.address=127.0.0.1
	${ASADMIN} set-hazelcast-configuration --enabled=false


# don't stop the domain, because we need it running for the update script
#read -p "--- Press [Enter] to continue..."
#${PAYARA_HOME}/bin/asadmin stop-domain --domaindir ${DOMAINS_HOME} ${DOMAIN_NAME}

echo "Server setup completed."
echo "Commands to start and stop the domain: "
if [ ${LINUX} = true ]; then
	echo "service payara-sormas start"
	echo "service payara-sormas stop"
else
	echo "${DOMAIN_DIR}/start-payara-sormas.sh"
	echo "${DOMAIN_DIR}/stop-payara-sormas.sh"
fi
echo "---"
echo "Please make sure to perform the following steps:"
echo "  - Adjust the sormas.properties file to your system"
echo "  - Execute the sormas-update.sh file to populate the database and deploy the server"



/bin/bash
