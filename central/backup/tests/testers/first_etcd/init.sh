#!/bin/sh
set -x
sleep 5
etcdctl user add root --new-user-password=password
etcdctl put /a/b Poland
etcdctl put /a/b/c China
etcdctl put /a/c Germany
etcdctl get / --prefix
etcdctl auth enable
etcdctl get / --prefix --user=root --password=password
