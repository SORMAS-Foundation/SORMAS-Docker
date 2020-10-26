FROM postgres:10-alpine

RUN echo "@old http://dl-cdn.alpinelinux.org/alpine/v3.10/community" >> /etc/apk/repositories && \
    apk update --no-cache && \
    apk upgrade --no-cache && \
    apk add --no-cache openssl curl tzdata py-pip postgresql-dev postgresql-contrib make gcc musl-dev py2-psutil@old && \
    pip install pgxnclient && \
    pgxnclient install temporal_tables
    
COPY psql.conf /etc/postgresql/postgresql.conf
COPY alter_system.py /usr/local/bin/
COPY tuning_parameters.conf /etc/postgresql/
COPY setup_sormas.sh /docker-entrypoint-initdb.d/
COPY docker-entrypoint.sh /usr/local/bin/
