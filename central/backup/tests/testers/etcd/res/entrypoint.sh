#!/bin/bash
set -x
CMD=$1

case $CMD in
    plain|auth)
        /res/setup.sh $CMD &
        /usr/local/bin/etcd --config-file /res/etcd.yml
        ;;

    secured)
        mkdir /certs
        cd /certs
        openssl req \
            -nodes \
            -newkey rsa:2048 \
            -keyout server.key \
            -x509 \
            -days 365 \
            -out server.crt \
            -subj "/CN=etcd_secured" \
            -addext "subjectAltName = DNS:etcd_secured"
        openssl x509 -in server.crt -text -noout
        cd /

        /res/setup.sh $CMD &
        /usr/local/bin/etcd --config-file /res/etcd-secured.yml
        ;;

    *)
        echo "CMD \"$CMD\" is not know"
        exit -1
        ;;
esac
