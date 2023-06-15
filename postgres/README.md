<p align="center">
  <a href="https://sormas.org/">
    <img
      alt="SORMAS - Surveillance, Outbreak Response Management and Analysis System"
      src="../logo.png"
      height="200"
    />
  </a>
</p>

# Container Postgres

The postgres container is build from image `postgres:10-alpine`.  It uses a prepared `/etc/postgresql/postgresql.conf` file with parameter:

```shell
max_prepared_transactions = 110         # zero disables the feature
```

This is needed to successfully deploy sormas.

During initial setup `/docker-entrypoint-initdb.d/setup_sormas.sh`  is executed. Here the sormas user and databases will get created and configured.

```sql
CREATE USER ${SORMAS_POSTGRES_USER} WITH PASSWORD '${SORMAS_POSTGRES_PASSWORD}' CREATEDB;
CREATE DATABASE ${DB_NAME} WITH OWNER = '${SORMAS_POSTGRES_USER}' ENCODING = 'UTF8';
\c ${DB_NAME}
CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;
ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO ${SORMAS_POSTGRES_USER};
CREATE EXTENSION pg_trgm;
CREATE EXTENSION pgcrypto;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO ${SORMAS_POSTGRES_USER};
```

<p align="center">
  <a href="https://sormas.org/">
    <img
      src="https://www.grouplink.de/wp-content/uploads/2014/01/logo_netzlink-300x300.jpg"
      title="netzlink-Logo_weißrot"
      alt="netzlink-Logo_weißrot"
      height="200"
    />
  </a>
</p>

# Environment variables

These configurations of postgres can be passed to container via environment variables. For more information about them, please refer to postgres documentation.
* SUPERUSER_RESERVED_CONNECTIONS
* EFFECTIVE_IO_CONCURRENCY
* RANDOM_PAGE_COST
* BGWRITER_DELAY
* BGWRITER_LRU_MAXPAGES
* BGWRITER_LRU_MULTIPLIER
* BGWRITER_FLUSH_AFTER
* IDLE_IN_TRANSACTION_SESSION_TIMEOUT
