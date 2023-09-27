FROM postgres:14.9-alpine3.17

RUN apk update --no-cache && \
    apk upgrade --no-cache && \
# this line below keeping fixed musl lib version is unnecessary under docker 20.10.3+ but musl-dev has to be normally included in apk add, then
    apk add --no-cache --repository  http://dl-cdn.alpinelinux.org/alpine/v3.13/main/ 'musl<1.2.2-r3' 'musl-dev<1.2.2-r3' && \
    apk add --no-cache openssl curl tzdata py-pip python3-dev postgresql-dev postgresql-contrib make gcc py3-psutil 
    

COPY psql.conf /etc/postgresql/postgresql.conf
COPY alter_system.py /usr/local/bin/
COPY tuning_parameters.conf /etc/postgresql/
COPY setup_sormas.sh /docker-entrypoint-initdb.d/
COPY update_sormas.sh /docker-entrypoint-updatedb.d/
COPY docker-entrypoint.sh /usr/local/bin/
