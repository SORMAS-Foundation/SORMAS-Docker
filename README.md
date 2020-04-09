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

### CPU and Memory resource limits

#### Java Application Server Heap Size
The heap size for the SORMAS application server is specified via 

**JVM_MAX**: Maximum heap space to be used for the java application server used by SORMAS. (For example 4096M for 4096MB). 

*Please ensure that this is below the avilable memory limit for this process, which can be limited either due to actual
physical resource constrains, or by using the cgroups mechanism below.

#### Cgroups based resource limits

Memory and CPU resource limitation are performed via the cgroups subsystem. It is possible to apply limits per
service or collectively over multiple services. **This should be done before you run docker-compose up** 

#### Requirements for resource limitation 

In order to be able to create and configure cgroups, the **cgcreate** tool has to be installed on the docker
host system. This is available on all major Linux distributions, but they might differ in how it is installed.

 * Ubuntu (16.04+): cgcreate is part of the *cgroup-tools* package. Install via **sudo apt install cgroup-tools**. See [Ubuntu cgcreate manpage](http://manpages.ubuntu.com/manpages/bionic/man1/cgcreate.1.html)
 * RedHat Enterprise Linux 7+: cgcreate seems to be preinstalled. See [RHEL7 - Introduction to Cgroups](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/resource_management_guide/chap-introduction_to_control_groups)

In doubt, please refer to your Linux distribution's documentation.

#### What if I cannot meet the requirements for cgroups usage ?

In this case, enforcing resource limits is not possible this way. **You can still run sormas without**. 

#### Resource Limit Configuration

For every service, specify a named cgroup via the following configuration options:

 * **SORMAS_CGROUP**: Cgroup name for the sormas application server.
 * **POSTGRES_CGROUP**: Cgroup name for the PostgreSQL database server. 
 * **PG_DUMP_CGROUP**: Cgroup name for the PG_DUMP service.
 * **APACHE2_CGROUP**: Cgroup name for the apache2 webserver.

**Example**
```
SORMAS_CGROUP=SORMAS_TEST_APPSERVER
POSTGRES_CGROUP=SORMAS_TEST_DB
PG_DUMP_CGROUP=SORMAS_TEST_DUMP
APACHE2_CGROUP=SORMAS_TEST_WEBSERVER
```

For *each* of these groups, you may then specify configuration options which specify resource limits and CPU shares. 

Replace **CGNAME** below with the name of the actual Cgroup(s) you specified for the services above.

**CGNAME**_CPUS: Number of CPUs to use for this Cgroup as a floating point number (values like 0.5 are possible). This is a soft limit. If more CPUs are free, they may be used.
**CGNAME**_MEM_MB: Memory limit in MB for this Cgroup. 

**Example**
```
SORMAS_TEST_APPSERVER_CPUS=6.0
SORMAS_TEST_APPSERVER_MEM_MB=4500

SORMAS_TEST_DB_CPUS=6.0
SORMAS_TEST_DB_MEM_MB=3000

SORMAS_TEST_DUMP_CPUS=0.5
SORMAS_TEST_DUMP_MEM_MB=500

SORMAS_TEST_WEBSERVER_CPUS=6.0
SORMAS_TEST_WEBSERVER_MEM_MB=500
```

#### Creating the Cgroups for resource limits

In order to create the cgroups, the script **sormas_cgroups** automates this process. 

Once the configuration has been written or it has been updated, run this script with superuser
privileges:

```
sudo ./sormas_cgroups
```
Just like docker-compose, the script requires an existing python interpreter (2.7+ or 3.x ). It also requires the
cgroups tool to be installed (see above). It is not possible to run it successfully without superuser privileges 
(e.g. you need to run it as root or via sudo )

**Important** there is no linux-vendor agnostic way of persisting cgroups. Therefore this command should also be run
after each reboot of the host machine, before executing docker-compose up.

