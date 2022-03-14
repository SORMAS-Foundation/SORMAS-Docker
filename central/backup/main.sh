#!/bin/sh
set -e

#TODO Add readme for this image - remember to add description of tests
#TODO Add comments inside code
#TODO Investigate if visible password for ETCD access could stay (probably yes)
#TODO Investigate if it is really required to check ETCD certificate (probably no)

GetContainerLabel() {
    CONTAINER_ID=$1
    LABEL=$2
    docker inspect --format="{{index .Config.Labels \"$LABEL\"}}" $CONTAINER_ID
}

GetComposeService() {
    CONTAINER_ID=$1
    docker inspect --format='{{index .Config.Labels "com.docker.compose.service"}}' $CONTAINER_ID
}

GetContainerEnv() {
    CONTAINER_ID=$1
    ENV=$2
    docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' $CONTAINER_ID | grep $ENV | sed 's/^.*=//'
}

GetBackupLabeledContainers() {
    TYPE=$1
    docker container ls --filter "label=backup.type=$TYPE" --format='{{json .ID}}' | tr -d '"'
}

GetDatabasesToBackup() {
    psql -l -t | cut -d '|' -f 1 | tr -d '[[:blank:]]' | grep -v -E "postgres|template0|template1" | sed '/^$/d'
}

CleanOldDumps() {
    DUMP_DIR=$1
    DUMPS_TO_REMOVE=$(ls $DUMP_DIR | head -n -$MAX_DUMPS)
    for DUMP in $DUMPS_TO_REMOVE; do
        echo "Removing old dump \"$DUMP\""
        rm $DUMP_DIR/$DUMP
    done
}

DumpDatabase() {
    SERVICE=$1
    DATABASE=$2
    mkdir -p /backup/postgres/$SERVICE/$DATABASE
    pg_dump $DATABASE | zstd > /backup/postgres/$SERVICE/$DATABASE/$SERVICE.$DATABASE.$DATE.zst
}

CleanDatabaseDumps() {
    SERVICE=$1
    DATABASE=$2
    CleanOldDumps /backup/postgres/$SERVICE/$DATABASE
}

DumpETCD() {
    SERVICE=$1
    ETCD_FLAGS=$2
    mkdir -p /backup/etcd/$SERVICE

    TMP_BACKUP=$(mktemp -u)
    etcdctl snapshot save $TMP_BACKUP $ETCD_FLAGS &>/dev/null
    zstd -q --rm $TMP_BACKUP -o /backup/etcd/$SERVICE/$SERVICE.etcd.$DATE.zst
}

CleanETCDDumps() {
    SERVICE=$1
    CleanOldDumps /backup/etcd/$SERVICE
}

######################################################################################################################################################
### Main
######################################################################################################################################################

export DATE=$(date +%F-%T)
MAX_DUMPS=${MAX_DUMPS:-60} # Should backups around two days worth of backups with default settings

##################################################
### Postgres backups
##################################################

for CONTAINER_ID in $(GetBackupLabeledContainers postgres); do
    SERVICE=$(GetComposeService $CONTAINER_ID)
    POSTGRES_USER=$(GetContainerEnv $CONTAINER_ID POSTGRES_USER)
    POSTGRES_PASSWORD=$(GetContainerEnv $CONTAINER_ID POSTGRES_PASSWORD)

    export PGUSER=$POSTGRES_USER
    export PGPASSWORD=$POSTGRES_PASSWORD
    export PGHOST=$CONTAINER_ID

    for DATABASE in $(GetDatabasesToBackup); do
        DumpDatabase $SERVICE $DATABASE
        CleanDatabaseDumps $SERVICE $DATABASE
    done
done

##################################################
### ETCD backups
##################################################

for CONTAINER_ID in $(GetBackupLabeledContainers etcd); do
    SERVICE=$(GetComposeService $CONTAINER_ID)
    ETCD_USER=$(GetContainerLabel $CONTAINER_ID backup.user)
    ETCD_PASSWORD=$(GetContainerLabel $CONTAINER_ID backup.password)
    ETCD_ENCRYPTED=$(GetContainerLabel $CONTAINER_ID backup.encrypted)

    ETCD_FLAGS=""
    if [ "$ETCD_USER" != "" ] && [ "$ETCD_PASSWORD" != "" ]; then
        ETCD_FLAGS="--user=$ETCD_USER --password=$ETCD_PASSWORD"
    fi

    if [ "$ETCD_ENCRYPTED" == "true" ]; then
        ETCD_FLAGS="$ETCD_FLAGS --endpoints=https://$SERVICE:2379 --insecure-transport=false --insecure-skip-tls-verify"
    else
        ETCD_FLAGS="$ETCD_FLAGS --endpoints=http://$SERVICE:2379"
    fi

    DumpETCD $SERVICE "$ETCD_FLAGS"
    CleanETCDDumps $SERVICE
    #TODO add checking for errors
done
