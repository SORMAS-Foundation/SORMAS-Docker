FROM postgres:10-alpine

RUN apk update --no-cache && \
    apk upgrade --no-cache && \
    apk add --no-cache --repository  http://dl-cdn.alpinelinux.org/alpine/v3.13/main/ 'musl<1.2.2-r3' 'musl-dev<1.2.2-r3' && \
    apk add --no-cache openssl curl tzdata py-pip postgresql-dev postgresql-contrib make gcc py3-psutil && \
    pip install pgxnclient && \
    pgxnclient install temporal_tables
    
COPY psql.conf /etc/postgresql/postgresql.conf
COPY alter_system.py /usr/local/bin/
COPY tuning_parameters.conf /etc/postgresql/
COPY setup_sormas.sh /docker-entrypoint-initdb.d/
COPY docker-entrypoint.sh /usr/local/bin/
