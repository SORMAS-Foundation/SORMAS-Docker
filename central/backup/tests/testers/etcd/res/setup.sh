#!/bin/sh
set -x
CMD=$1
sleep 5

case $CMD in
    plain)
        etcdctl put /a/b Poland
        etcdctl put /a/b/c China
        etcdctl put /a/c Germany
        etcdctl get / --prefix
        ;;

    auth)
        etcdctl user add root --new-user-password=second_password
        etcdctl put /x/y Atlantic
        etcdctl put /x/y/z Baltic
        etcdctl put /x/z Narnia
        etcdctl get / --prefix
        etcdctl auth enable
        etcdctl get / --prefix --user=root --password=second_password
        ;;

    secured)
        etcdctl --endpoints=https://etcd_secured:2379 --cacert=/certs/server.crt user add root --new-user-password=secured_password
        etcdctl --endpoints=https://etcd_secured:2379 --cacert=/certs/server.crt put /1/2 Rivest
        etcdctl --endpoints=https://etcd_secured:2379 --cacert=/certs/server.crt put /1/2/3 Shamir
        etcdctl --endpoints=https://etcd_secured:2379 --cacert=/certs/server.crt put /1/3 Adleman
        etcdctl --endpoints=https://etcd_secured:2379 --cacert=/certs/server.crt get / --prefix
        etcdctl --endpoints=https://etcd_secured:2379 --cacert=/certs/server.crt auth enable
        etcdctl --endpoints=https://etcd_secured:2379 --cacert=/certs/server.crt get / --prefix --user=root --password=secured_password
        ;;
    *)
        echo "CMD \"$CMD\" is not know"
        exit 1
        ;;
esac
