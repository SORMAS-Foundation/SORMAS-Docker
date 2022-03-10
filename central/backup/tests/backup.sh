#!/bin/bash

set -x
PS4="\n>>>>>> "

docker-compose exec backup sh -c "rm -fr /backup/*"
docker-compose exec backup /main.sh
docker-compose exec backup tree -C /backup
docker-compose exec backup date
