FROM alpine:3.8

RUN apk add --no-cache postgresql-client dcron

COPY pg_dump /etc/periodic/15min/pg_dump
COPY entrypoint.sh /entrypoint.sh
COPY root /etc/crontabs/root

ENTRYPOINT ["/entrypoint.sh" ]
CMD [ "/usr/sbin/crond", "-f" ]
