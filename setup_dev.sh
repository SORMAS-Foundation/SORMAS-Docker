#!/bin/sh


cp /root/.env /root/SORMAS-docker/
cp /root/docker-compose.yml /root/SORMAS-docker/

sed -i "s/SORMAS_VERSION=.*/SORMAS_VERSION=$1/" /root/SORMAS-docker/.env
