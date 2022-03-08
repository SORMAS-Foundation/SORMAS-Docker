#!/bin/sh

echo "Entrypoint!"
/init.sh &
/usr/local/bin/etcd
