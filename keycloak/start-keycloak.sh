#!/bin/bash
set -e

/update-realm.sh &

# --import-realm imports all realm JSON files provided in data/import https://www.keycloak.org/server/containers#_importing_a_realm_on_startup
# --hostname-strict-https b/c of keycloak/keycloak#11922
# --http-enabled / --proxy for HTTP between reverse proxy and the container
/opt/keycloak/bin/kc.sh start --optimized --import-realm \
 --hostname-strict-https=false --http-enabled=true --proxy=edge \
 --log-level=INFO,org.keycloak.events:DEBUG