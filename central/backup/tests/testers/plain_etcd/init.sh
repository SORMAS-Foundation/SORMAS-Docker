#!/bin/sh
set -x
sleep 5
etcdctl put /a/b Poland
etcdctl put /a/b/c China
etcdctl put /a/c Germany
etcdctl get / --prefix
