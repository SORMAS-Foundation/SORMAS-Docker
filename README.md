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

**SORMAS** (Surveillance Outbreak Response Management and Analysis System) is an open source eHealth system - consisting of separate web and mobile apps - that is geared towards optimizing the processes used in monitoring the spread of infectious diseases and responding to outbreak situations.

## Project Objectives
This project aims to build docker images for the SORMAS application.

## Firewall
 
The host running the Docker installation with the SORMAS application should be behind a external firewall. Several containers open ports on the underlying host and circumvent the local firewall on the host (iptables).

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
4. As the user running docker-compose create these directories:
```
mkdir /srv/dockerdata/sormas/psqldata
mkdir /srv/dockerdata/sormas/sormas-backup
mkdir /srv/dockerdata/sormas/sormas-web

```

### Start the application
1. Check out this repository
2. Open a Shell in the projects root directory (the directory containing the docker-compose.yml
3. Type in 
```
docker-compose up
```
### Default Logins
These are the default users for demo systems. Make sure to deactivate them or change the passwords on productive systems:

Admin
name: admin pw: sadmin

Surveillance Supervisor (web UI)
name: SunkSesa pw: Sunkanmi

Surveillance Officer (mobile app)
name: SanaObas pw: Sanaa

## Advanced Installation

To change some parameters edit the .env before running the docker-compose

These Options are available to customize the installation:

### Database
SORMAS_POSTGRES_USER: User for the SORMAS Databases

SORMAS_POSTGRES_PASSWORD: Password for this User

DB_NAME: Name of the database for the SORMAS data

DB_NAME_AUDIT: Name of the database for SORMAS audit data 

DB_HOST: Hostname or IP if the database host
### SORMAS
SORMAS_VERSION: Version of SORMAS that should be installed (Dockerimages are provided starting from the Version 1.33.0)

SORMAS_SERVER_URL: URL under which the SORMAS installation should be accessed

DOMAIN_NAME: Name of the Domain in the Payara Server

LOCALE: Default language of the SORMAS server 

EPIDPREFIX: Prefix for the data

MAIL_HOST: Hostname or IP of the SMTP host

SEPARATOR: CSV separator 

EMAIL_SENDER_ADDRESS: email from which the mail is going to be send

EMAIL_SENDER_NAME: Name of the sender of the email

LATITUDE: Latitude of the map center

LONGITUDE: Logitude of the map center

SORMAS_PATH: Path to store the Dockervolumes 

JVM_MAX: Maximum amount of RAM given to the JVM


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
your 
