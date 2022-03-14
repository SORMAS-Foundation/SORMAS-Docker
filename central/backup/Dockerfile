FROM alpine:3.15.0 as builder
ADD https://github.com/etcd-io/etcd/releases/download/v3.5.2/etcd-v3.5.2-linux-amd64.tar.gz /etcd-v3.5.2-linux-amd64.tar.gz
RUN tar xzvf /etcd-v3.5.2-linux-amd64.tar.gz

######################################################################################################################################################

FROM alpine:3.15.0

# Packages installation from repository
RUN apk add docker-cli postgresql-client zstd tree

# etcdctl installation
COPY --from=builder etcd-v3.5.2-linux-amd64 /etcd
RUN ln -s /etcd/etcdctl /usr/bin/etcdctl

# Scripts
COPY main.sh /main.sh

# Entrypoint and command configuration
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD [ "/usr/sbin/crond", "-f" ]

VOLUME "/backup"
