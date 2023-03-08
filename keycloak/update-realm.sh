#!/bin/bash

KCADM="/opt/keycloak/bin/kcadm.sh"

until $(${KCADM} config credentials --server http://localhost:8080/keycloak \
 --user ${KEYCLOAK_ADMIN} --password ${KEYCLOAK_ADMIN_PASSWORD} --realm master &> /dev/null);
do
    sleep 5s
done

${KCADM} create partialImport -r SORMAS -s ifResourceExists=SKIP -o -f /opt/keycloak/data/import/SORMAS.json