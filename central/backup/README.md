# S2S central backup

This image is created to provide S2S central backup functionality.

## Main responsibility

Main responsibility of this images are:
* backup of postgres database
* backup of ETCD cluster
* removal of old backups

## Image features

There are two noteworthy features of docker image: cron configuration and volume for backups storing.

### Cron

Backup is triggered via internal cron job. It's default configuration can be described via this snippet:

```
# min     hour      day     month     weekday command
${MIN}    ${HOUR}   *       *         *       /main.sh >> /log 2>&1
```

where MIN is selected randomly in range of "1-20,31-59" and HOUR is "0,4,7,8,9,10,11,12,13,14,15,16,17,18,20".

To change this configuration, use environment variables MIN and HOUR, e.g.

MIN=1,4

HOUR=*

### Volume

By default docker image has one anonymous volume mounted at internal directory **/backup**.

## Postgres backups

Postgres backups are done for every container labeled **backup.type=postgres** (see [example](tests/docker-compose.yml)).

Postgres container needs these environment variables to be defined:
* POSTGRES_USER
* POSTGRES_PASSWORD

Backups are done for all databases visible for POSTGRES_USER in postgres instance besides default ones:
* postgres
* template0
* template1

## ETCD backup

ETCD backups are done for every container labeled **backup.type=etcd** (see [example](tests/docker-compose.yml)).

Postgres container needs these labels to be defined:
* backup.user - etcd user with right to read everything
* backup.password - if user is defined, this label has to be also defined
* backup.encrypted - indicates, that https has to be used (certificate is not validated)

## Removal of old backups

As disk space is not unlimited, removal of old backups is introduced. When quantity of backups for each database or etcd cluster is reached, oldest backup is removed. This threshold can be configured via environment variable **MAX_DUMPS**. If this variable is not defined, it is taking value of 60. With default cron configuration it will provide around 2 days worth of backups.

## Tests

In directory you can find scripts and additional resources which supports manual testing of this image.

### docker-compose.yml

This manifest contains example of deployment.

### start.sh

Helper script used to start local deployment used for testing. Noteworthy is that **main.sh** script is mounted as volume. This enables to changing backup behavior "on the fly".

### check.sh

This script is showing current contents of test databases and etcd clusters.

### backup.sh

This script removes all backups, trigger backup mechanism once and shows content of **/backup** directory in tree format.

### backup-multiple.sh

This script removes all backups, trigger backup mechanism couple of times and shows content of **/backup** directory in tree format.
