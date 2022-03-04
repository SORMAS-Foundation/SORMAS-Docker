#!/bin/bash

set -x
PS4="\n>>>>>> "

docker-compose exec first_postgres psql -U first_user first_default_database -c '\dt;'
docker-compose exec first_postgres psql -U first_user first_database_created_by_init -c 'SELECT * FROM Persons;'

docker-compose exec second_postgres psql -U second_user second_default_database -c '\dt;'
docker-compose exec second_postgres psql -U second_user second_database_created_by_init -c 'SELECT * FROM Persons;'

docker-compose exec plain_etcd etcdctl get / --prefix
docker-compose exec auth_etcd etcdctl get / --prefix --user=root --password=second_password
#https://github.com/etcd-io/etcd/issues/11693#issuecomment-825653253
docker-compose exec secured_etcd etcdctl --insecure-transport=false --insecure-skip-tls-verify get / --prefix --user=root --password=secured_password
