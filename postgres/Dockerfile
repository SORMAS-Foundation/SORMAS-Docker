FROM postgres:10.18-alpine

COPY psql.conf /etc/postgresql/postgresql.conf
COPY alter_system.py /usr/local/bin/
COPY tuning_parameters.conf /etc/postgresql/
COPY setup_sormas.sh /docker-entrypoint-initdb.d/
COPY docker-entrypoint.sh /usr/local/bin/
