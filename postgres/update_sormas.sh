#!/bin/bash
set -e

# Set up the database
echo "Starting database modification..."

psql -v ON_ERROR_STOP=0 --username "postgres" <<EOSQL
    \c ${DB_NAME}
    ALTER FUNCTION public.versioning() OWNER TO ${SORMAS_POSTGRES_USER};
EOSQL
