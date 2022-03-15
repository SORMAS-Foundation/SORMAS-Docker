#!/bin/bash

ITERATION=${1:-30}

set -x
PS4="\n>>>>>> "

docker-compose exec backup sh -c "rm -fr /backup/*"
for i in $(seq 1 $ITERATION); do
    echo ">>>>>> $i/$ITERATION"
    docker-compose exec backup /main.sh
done
docker-compose exec backup tree -C /backup
docker-compose exec backup date
