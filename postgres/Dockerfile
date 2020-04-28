FROM postgres:10-alpine

RUN apk add --no-cache openssl curl tzdata py-pip postgresql-dev postgresql-contrib make gcc musl-dev && \
    pip install pgxnclient && \
    pgxnclient install temporal_tables
    
COPY psql.conf /etc/postgresql/postgresql.conf
COPY setup_sormas.sh /docker-entrypoint-initdb.d/
