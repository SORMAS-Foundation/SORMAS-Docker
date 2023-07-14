<p align="center">
  <a href="https://sormas.org/">
    <img
      alt="SORMAS - Surveillance, Outbreak Response Management and Analysis System"
      src="../logo.png"
      height="200"
    />
  </a>
</p>

# Database

Sormas uses postgres as database backend.

## Configuration

### Default configuration

Database related values set in `.env`file:

* Database server: `DB_HOST`: postgres
* Sormas Database: `DB_NAME`: sormas
* Sormas Database User: `SORMAS_POSTGRES_USER`: sormas_user
* Sormas Database Password: `SORMAS_POSTGRES_PASSWORD`: password

### Parameters for containers

Several parameters are configured in `docker-compose.yml`:

#### Database

The `postgres` container is set up with the `SORMAS_POSTGRES_PASSWORD` from the `.env` file. The `sormas` DB is created and initialized. The `sormas` user gets created.

Additionally, the `postgres`container listens on localhost port 5432. This can be used to access the `sormas` database e.g. for creating local DB dumps.

Database files for `sormas` are held on the host in a local folder.

```yaml
services:
  postgres:
    environment:
      - POSTGRES_PASSWORD=${SORMAS_POSTGRES_PASSWORD}
      - DB_NAME=sormas
      - SORMAS_POSTGRES_PASSWORD=${SORMAS_POSTGRES_PASSWORD}
      - SORMAS_POSTGRES_USER=${SORMAS_POSTGRES_USER}
    ports:
      - "127.0.0.1:5432:5432"
    volumes:
      - ${SORMAS_PATH}/psqldata:/var/lib/postgresql/data
```

#### pg_dump container

In the default installation a pg_dump container is started. This container dumps all database on the host (except postgres and template) on a regular basis to a folder on the host (`/backup`). 

```yaml
services:
  pg_dump:
    environment:
      - DB_HOST=${DB_HOST}
      - PGPASSWORD=${SORMAS_POSTGRES_PASSWORD}
      - POSTGRES_USER=${SORMAS_POSTGRES_USER}
      - MIN=15,45 # Twice the hour on 15 and 45 (use crontab notation)
      - HOUR= # Keep empty for every hour. Use crontab notation otherwise
    volumes:
      - /backup:/var/opt/db_dumps
```

#### sormas

The `sormas` container uses postgres informations from the `.env` file.

```yaml
services:
  sormas:
    environment:
      - SORMAS_POSTGRES_USER=${SORMAS_POSTGRES_USER}
      - SORMAS_POSTGRES_PASSWORD=${SORMAS_POSTGRES_PASSWORD}
      - DB_HOST=${DB_HOST}
      - DB_NAME=${DB_NAME}

```
### partner

<p align="center">
  <a href="https://netzlink.com/">
   <img
        src="../Netzlink Logo Weiss-Rot.png"
        height="200"
        />
  </a>
</p>

