FROM alpine:3.8

RUN apk add --no-cache postgresql-client dcron tzdata gzip

COPY pg_dump /root
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh" ]
CMD [ "/usr/sbin/crond", "-f" ]
