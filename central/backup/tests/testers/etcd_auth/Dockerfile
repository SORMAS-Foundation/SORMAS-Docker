FROM quay.io/coreos/etcd:v3.5.0

RUN apt update && apt install -y bash

COPY entrypoint.sh /entrypoint.sh
COPY init.sh /init.sh
ENTRYPOINT /entrypoint.sh
CMD /usr/local/bin/etcd
