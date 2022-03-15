#!/usr/bin/env bash

INIT_TYPE=$1

case $INIT_TYPE in
    first)
        cp /res/first.sql /docker-entrypoint-initdb.d/
        ;;
    second)
        cp /res/second.sql /docker-entrypoint-initdb.d/
        ;;
esac

/usr/local/bin/docker-entrypoint.sh postgres
