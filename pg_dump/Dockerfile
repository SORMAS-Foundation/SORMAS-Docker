FROM alpine:3.8

RUN apk add --no-cache postgresql-client dcron

COPY pg_dump /etc/periodic/hourly/pg_dump
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh" ]
CMD [ "/usr/sbin/crond", "-f" ]
