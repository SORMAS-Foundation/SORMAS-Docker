#!/bin/bash

set -x
PS4="\n>>>>>> "

docker-compose exec postgres_first psql -U first_user first_default_database -c '\dt;'
docker-compose exec postgres_first psql -U first_user first_database_created_by_init -c 'SELECT * FROM Persons;'

docker-compose exec postgres_second psql -U second_user second_default_database -c '\dt;'
docker-compose exec postgres_second psql -U second_user second_database_created_by_init -c 'SELECT * FROM Persons;'

docker-compose exec etcd_plain etcdctl get / --prefix
docker-compose exec etcd_auth etcdctl get / --prefix --user=root --password=second_password
#https://github.com/etcd-io/etcd/issues/11693#issuecomment-825653253
docker-compose exec etcd_secured etcdctl --insecure-transport=false --insecure-skip-tls-verify get / --prefix --user=root --password=secured_password
