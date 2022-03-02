#!/bin/bash

set -x
PS4="\n>>>>>> "

docker-compose exec backup rm -fr /backup
docker-compose exec backup /main.sh
docker-compose exec backup find /backup
docker-compose exec backup date
