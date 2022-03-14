#!/bin/bash

set -x
PS4="\n>>>>>> "

docker-compose exec backup sh -c "rm -fr /backup/*"
for i in $(seq 1 30); do
    echo ">>>>>> $i"
    docker-compose exec backup /main.sh
done
docker-compose exec backup tree -C /backup
docker-compose exec backup date
