#!/bin/sh
set -x
sleep 5
etcdctl user add root --new-user-password=second_password
etcdctl put /x/y Atlantic
etcdctl put /x/y/z Baltic
etcdctl put /x/z Narnia
etcdctl get / --prefix
etcdctl auth enable
etcdctl get / --prefix --user=root --password=second_password
