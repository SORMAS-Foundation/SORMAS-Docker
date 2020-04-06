#!/bin/sh


cp /home/deploy/.env /home/deploy/SORMAS-Docker/
cp /home/deploy/docker-compose.yml /home/deploy/SORMAS-Docker/

sed -i "s/SORMAS_VERSION=.*/SORMAS_VERSION=$1/" /home/deploy/SORMAS-Docker/.env

docker-compose -f /home/deploy/SORMAS-Docker/docker-compose-build.yaml build
docker-compose -f /home/deploy/SORMAS-Docker/docker-compose.yaml up -d
