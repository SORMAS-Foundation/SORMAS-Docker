#! /bin/#!/usr/bin/env bash

source ./.env
mkdir -p ./letsencrypt/certs/${SORMAS_SERVER_URL}
cp ./apache2/certs/${SORMAS_SERVER_URL}.crt ./letsencrypt/certs/${SORMAS_SERVER_URL}/fullchain.pem
cp ./apache2/certs/${SORMAS_SERVER_URL}.key ./letsencrypt/certs/${SORMAS_SERVER_URL}/privkey.pem
