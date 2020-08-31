#!/bin/bash
set -e

# Set up the database
echo "Starting keycloak database setup..."

psql -v ON_ERROR_STOP=1 --username "postgres" <<EOSQL
    CREATE USER ${KEYCLOAK_DB_USER} WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}' CREATEDB;
    CREATE DATABASE ${KEYCLOAK_DB_NAME} WITH OWNER = '${KEYCLOAK_DB_USER}' ENCODING = 'UTF8';
EOSQL
