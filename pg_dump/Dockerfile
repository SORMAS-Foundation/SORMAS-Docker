FROM alpine:3.8

RUN apk update --no-cache && \
    apk upgrade --no-cache && \
    apk add --no-cache --upgrade postgresql-client dcron tzdata pigz

COPY pg_dump /root
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh" ]
CMD [ "/usr/sbin/crond", "-f" ]
