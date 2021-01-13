#!/bin/bash

KCADM="/opt/jboss/keycloak/bin/kcadm.sh"

until $(curl --output /dev/null --silent --head --fail http://localhost:8080/keycloak/auth); do
    sleep 10s
done

${KCADM} config credentials --server http://localhost:8080/keycloak/auth --user ${KEYCLOAK_USER} --password ${KEYCLOAK_PASSWORD} --realm master
${KCADM} create partialImport -r SORMAS -s ifResourceExists=SKIP -o -f ./SORMAS.json