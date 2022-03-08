#!/bin/sh
set -x
sleep 5
etcdctl --endpoints=https://secured_etcd:2379 --cacert=/certs/server.crt user add root --new-user-password=secured_password
etcdctl --endpoints=https://secured_etcd:2379 --cacert=/certs/server.crt put /1/2 Rivest
etcdctl --endpoints=https://secured_etcd:2379 --cacert=/certs/server.crt put /1/2/3 Shamir
etcdctl --endpoints=https://secured_etcd:2379 --cacert=/certs/server.crt put /1/3 Adleman
etcdctl --endpoints=https://secured_etcd:2379 --cacert=/certs/server.crt get / --prefix
etcdctl --endpoints=https://secured_etcd:2379 --cacert=/certs/server.crt auth enable
etcdctl --endpoints=https://secured_etcd:2379 --cacert=/certs/server.crt get / --prefix --user=root --password=secured_password
