#!/bin/sh


cp /home/deploy/.env /home/deploy/SORMAS-docker/
cp /home/deploy/docker-compose.yml /home/deploy/SORMAS-docker/

sed -i "s/SORMAS_VERSION=.*/SORMAS_VERSION=$1/" /home/deploy/SORMAS-docker/.env
