FROM postgres:10-alpine

RUN apk add --no-cache openssl curl py-pip postgresql-dev make gcc musl-dev && \
    pip install pgxnclient && \
    pgxnclient install temporal_tables

COPY psql.conf /etc/postgresql/postgresql.conf

