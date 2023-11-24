FROM alpine:3.17

RUN apk update --no-cache && \
    apk upgrade --no-cache && \
    apk add --no-cache --upgrade postgresql14-client tar dcron tzdata zstd

COPY pg_dump /root
COPY entrypoint.sh /entrypoint.sh
COPY prescripts.d /prescripts.d

ENTRYPOINT ["/entrypoint.sh" ]
CMD [ "/usr/sbin/crond", "-f" ]
