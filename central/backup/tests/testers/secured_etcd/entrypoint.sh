#!/bin/sh

mkdir /certs
cd /certs
openssl req \
    -nodes \
    -newkey rsa:2048 \
    -keyout server.key \
    -x509 \
    -days 365 \
    -out server.crt \
    -subj "/CN=secured_etcd" \
    -addext "subjectAltName = DNS:secured_etcd"
openssl x509 -in server.crt -text -noout
cd /

/init.sh &
# /usr/local/bin/etcd
/usr/local/bin/etcd --config-file /etc/etcd/etcd.yml
