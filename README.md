<p align="center">
  <a href="https://sormas.org/">
    <img
      alt="SORMAS - Surveillance, Outbreak Response Management and Analysis System"
      src="logo.png"
      height="200"
    />
  </a>
  <br/>
</p>
<br/>

# Docker Images for SORMAS

---
**NOTE**

For production usage, ONLY checkout from the release tags, because only these contain working and tested images!

---

**SORMAS** (Surveillance Outbreak Response Management and Analysis System) is an open source eHealth system - consisting of separate web and mobile apps - that is geared towards optimizing the processes used in monitoring the spread of infectious diseases and responding to outbreak situations.

## Project Objectives
This project aims to build docker images for the SORMAS application (https://github.com/sormas-foundation/SORMAS-Project)

## Firewall

The host running the Docker installation with the SORMAS application should be behind an external firewall. Several containers open ports on the underlying host and circumvent the local firewall on the host (iptables).

## Quick Start

If you would like to set up a local instance for testing, follow these instructions

### Prerequisites

In order to run the containerized SORMAS you need to have installed the following tools:

1. Docker (Version 19.3 is tested to run SORMAS)
2. docker-compose
3. Insert this line into your /etc/hosts file:
```
127.0.0.1	sormas-docker-test.com
```

### Start the application
1. Check out this repository
2. Open a Shell in the projects root directory (the directory containing the docker-compose.yml
3. Type in
```
docker-compose up
```
### Default Logins
There are the default users for demo systems. Make sure to deactivate them or change the passwords on productive systems:

Admin
name: admin
pw: sadmin

All default users are listed here:
https://github.com/sormas-foundation/SORMAS-Project/blob/master/docs/SERVER_UPDATE.md#default-logins

If you wish to provide a demologin page, copy the demologin.html to the custom folder (this page uses the default logins):
```
wget https://raw.githubusercontent.com/sormas-foundation/SORMAS-Project/master/sormas-base/setup/demologinmain.html -P /srv/dockerdata/sormas/custom
```

## Advanced Installation

To change some parameters edit the .env before running the docker-compose

These Options are available to customize the installation:

### Database
**SORMAS_POSTGRES_USER** User for the SORMAS databases

**SORMAS_POSTGRES_PASSWORD** Password for this user

**DB_NAME** Name of the database for the SORMAS data

**DB_NAME_AUDIT** Name of the database for SORMAS audit data

**DB_HOST** Hostname or IP of the database host

**DB_JDBC_MAXPOOLSIZE** Sets the maximum number of database connections

**DB_JDBC_IDLE_TIMEOUT** Sets the maximum timeout of client idle connections

### SORMAS
**SORMAS_VERSION** Version of SORMAS that should be installed (Dockerimages are provided starting from the Version 1.33.0)

**SORMAS_DOCKER_VERSION** Version of dockerimages (see https://github.com/sormas-foundation/SORMAS-Docker/releases for all release)

**SORMAS_SERVER_URL** URL under which the SORMAS installation should be accessed

**UI_URL** URL used in sms and email notifications. If not defined, it has value of **SORMAS_SERVER_URL**.

**DOMAIN_NAME** Name of the Domain in the Payara Server

**LOCALE** Default language of the SORMAS server

**EPIDPREFIX** Prefix for the data

**MAIL_HOST** Hostname or IP of the SMTP host

**SMTP_PORT** Port of the SMTP service used by log SMTPAppender and Payara notification emailing

**SMTP_USER** Username used by log SMTPAppender for authorization to SMTP service (email in case of Gmail as Relay)

**SMTP_PASSWORD** Password used by log SMTPAppender for authorization to SMTP service (email pass in case of Gmail as Relay)

**SMTP_STARTTLS** Enables (negotiates) switching to TLS from unencrypted mode (boolean -> true/false)

**SMTP_SSL** Enables SSL only (boolean -> true/false)

**SMTP_ASYNC_SENDING** Log SMTPAppender will send emails asynchronously (boolean -> true/false)

**SMTP_AUTH_ENABLED** Describes SMTP host user/password authentication for javamail resource Payara notifications (boolean -> true/false), mind that currently only false is supported

**EMAIL_NOTIFICATION_ENABLED** Enables javamail resource Payara notifications - general toggle (boolean -> true/false), have in mind that each of featureconfiguration notification has to be enabled in sormas db

**LOG_SENDER_ADDRESS** Specifies email FROM property of log SMTPAppender message

**LOG_RECIPIENT_ADDRESS** Specifies email TO property of log SMTPAppender message (if it is empty - error-log mail shipment is DISABLED)

**LOG_SUBJECT** Specifies SUBJECT property of log SMTPAppender message

**SEPARATOR** CSV separator

**EMAIL_SENDER_ADDRESS** Javamail resource Payara notification email address from which the mail is going to be send

**EMAIL_SENDER_NAME** Javamail resource Payara notification email's sender name

**LATITUDE** Latitude of the map center

**LONGITUDE** Longitude of the map center

**MAP_ZOOM** Zoom level of the map

**SORMAS_PATH** Path to store the Dockervolumes

**TZ** The timezone to choose (available timezones can be found here: https://nodatime.org/TimeZones)

**DEVMODE** Enables the devmode for testing

**JSON_LOGGING** Change the output of sormas server.log to JSON format

**PROMETHEUS_SERVERS** One or more ip-addresses of prometheus monitoring servers (to scrape metrics from payara) seperated by spaces. If you don't have one, just leave it at 127.0.0.1

**CREATE_DEFAULT_ENTITIES** Control the creation of the default entities

**NAMESIMILARITYTHRESHOLD** Use a value between 0 and 1 (the higher the value, the more restrictive the similarity search)

**CUSTOMBRANDING_ENABLED** Enables the custombranding feature

**CUSTOMBRANDING_NAME** Name of the custombranding

**CUSTOMBRANDING_LOGO_PATH** Path to the custom logo

**CUSTOMBRANDING_USE_LOGINSIDEBAR** Enables the customization of the loginsidebar

**CUSTOMBRANDING_LOGINBACKGROUND_PATH** Path to the custom loginsidebar image

**SORMAS2SORMAS_ENABLED** Enables the "Sormas to Sormas" feature

**SORMAS2SORMAS_KEYALIAS** Alias of the key

**SORMAS2SORMAS_KEYSTORENAME** Name of the used keystore

**SORMAS2SORMAS_KEYPASSWORD** Password for the keystore

**SORMAS2SORMAS_TRUSTSTORENAME** Name of the truststore

**SORMAS2SORMAS_TRUSTSTOREPASSWORD** Password for the truststore

**SORMAS2SORMAS_DIR** Path to the sormas to sormas directory

**SORMAS2SORMAS_DISTRICT_EXTERNALID** External id of the district to which the Cases/Contacts to be assigned when accepting a share request

**SORMAS_ORG_ID** ID of the organisiation

**SORMAS_ORG_NAME** Name of the organisation

**AUDIT_LOGGER_CONFIG** Config file path of the audit logger. Not specifying a value will effectively disable the audit log. Possible Values: any valid filesystem path, but prefer /opt/config/audit-logback.xml

### PIA
If you choose to align SORMAS with a PIA instance, use the docker-compose-sb.yml.
The following variables should be set.

**PIA_URL** Connection to a PIA (Symptom Journal) instance

**SJ_CLIENTID** Name of the PIA user SORMAS is supposed to login with in PIA

**SJ_SECRET** Password for the PIA user SORMAS is supposed to login with in PIA

**SJ_DEFAULT_USERNAME** Name of the SORMAS user the PIA instance is supposed to login with in SORMAS. This user will automatically be generated at server startup.

**SJ_DEFAULT_PASSWORD** Password for the SORMAS user the PIA instance is supposed to login with in SORMAS. The password will automatically be generated/updated at server startup.


### NGINX (experimental)
If you choose to use the nginx with built in certbot, use the docker-compose_nginx.yml.<br>
Please note this is still in experimental state und not tested in production.

**DISABLE_CERTBOT** Choose if nginx will generate LetsEncrypt certificates

**LETSENCRYPT_MAIL** Mail address for LetsEncrypt expiry notifications

**TZ** The timezone to chose (available timezones can be found here: https://nodatime.org/TimeZones)

### Keycloak (experimental)
If deploying SORMAS bundled with Keycloak use the docker-compose-keycloak.yml<br>
Please note this is still in experimental state und not tested in production.

#### Database for Keycloak
See also [keycloak-postgres](./keycloak-postgres/README.md)

**KEYCLOAK_DB_USER** User for the Keycloak database

**KEYCLOAK_DB_PASSWORD** Password of the Keycloak database user

**KEYCLOAK_DB_HOST** Hostname or IP of the Keycloak database host

**KEYCLOAK_DB_NAME** Name of the Keycloak database

**KEYCLOAK_DB_VENDOR** Vendor for the Keycloak database (postgres by default)

#### Keycloak server
**KEYCLOAK_ADMIN_USER** User for the Keycloak admin console

**KEYCLOAK_ADMIN_PASSWORD** Password for the Keycloak admin user

**KEYCLOAK_SORMAS_UI_SECRET** Secret code for the sormas-ui client

**KEYCLOAK_SORMAS_REST_SECRET** Secret code for the sormas-rest client. Also used by the SORMAS application

**KEYCLOAK_SORMAS_BACKEND_SECRET** Secret code for the sormas-backend client. Also used by the SORMAS application

#### SORMAS Configs for using with keycloak
**CACERTS_PASS** Password for Payara certificate store

**KEYSTORE_PASS** Password for Payara keystore

#### CPU and memory usage limitation for Keycloak
**KEYCLOAK_MEM** Maximum available memory for the Keycloak web server. (For example 1000M for 1000MB)

**KEYCLOAK_MEM_RESERVED** Memory reserved for the Keycloak web server. This memory may not be used by other processes on the same host. (For example 400M for 400MB)

**KEYCLOAK_CPUS**  CPU cores reserved for the Keycloak web server. This should be a floating point value. (Example: 3.0 )

**KEYCLOAK_DB_MEM** Maximum available memory for the Keycloak database server. (For example 3000M for 3000MB)

**KEYCLOAK_DB_MEM_RESERVED** Memory reserved for the Keycloak database server. This memory may not be used by other processes on the same host. (For example 2500M for 2500MB)

**KEYCLOAK_DB_CPUS** CPU cores reserved for the Keycloak database server. This should be a floating point value. (Example: 3.0 )


### Changing the host name

If you would like to run SORMAS using your own host name (e.g. https://sormas.example.com) , please follow these steps:

1. obtain a certificate and private key for the chosen host name using e.g. letsencrypt
2. copy the certificate file (e.g. fullchain.pem if you use letsencrpyt) to the ./apache2/certs directory using these filenames:
- [hostname].crt for the certificate file (e.g. sormas.example.com.crt)
- [hostname].key for the private key file (e.g. sormas.example.com.key)
3. set the environment variable SORMAS_SERVER_URL to the hostname you have chosen
4. make sure dns resolves to the host name you have chosen
4. run
```
docker-compose up -d
```

SORMAS should now be reachable via the given hostname.

#### CPU and memory usage limits and reservations

For all configuration options below, memory should be given as a positive integer number followed by an upper-case "M" - for example 1000M. CPU counts should be
given as a floating point value with the dot ( . ) as decimal separator, for example "2.5".

**APPSERVER_JVM_MAX** Maximum heap space to be used for the java application server used by SORMAS. (For example 4096M for 4096MB)

**APPSERVER_MEM** Maximum available memory for SORMAS application server. Should be set to be at least 150 MB above SORMAS_JVM_MAX. (For example 4300M for 4300MB)

**APPSERVER_MEM_RESERVED** Memory reserved for SORMAS application server. This memory may not be used by other processes on the same host. (For example 4300M for 4300MB)

**APPSERVER_CPUS** CPU cores reserved for the SORMAS java application server. This should be a floating point value. (Example: 2.0)

**WEBSERVER_MEM** Maximum available memory for the used web server. (For example 1000M for 1000MB)

**WEBSERVER_MEM_RESERVED** Memory reserved for the used web server. This memory may not be used by other processes on the same host. (For example 400M for 400MB)

**WEBSERVER_CPUS** CPU cores reserved for the used web server. This should be a floating point value. (Example: 2.0)

**DB_MEM** Maximum available memory for the used database server. (For example 3000M for 3000MB)

**DB_MEM_RESERVED** Memory reserved for the used database server. This memory may not be used by other processes on the same host. (For example 2500M for 2500MB)

**DB_CPUS** CPU cores reserved for the used web server. This should be a floating point value. (Example: 3.0 )

**DB_DUMP_MEM** Maximum available memory for the database dump tool. (For example 500M for 500MB)

**DB_DUMP_MEM_RESERVED** Memory reserved for the database dump tool. This memory may not be used by other processes on the same host. (For example 100M for 100MB)

**DB_DUMP_CPUS** CPU cores reserved for the used web server. This should be a floating point value. (Example: 0.5 )

Mind that services-base.yml file contains only the common set of environmental properties and settings for each of custom docker-compose.yml.
