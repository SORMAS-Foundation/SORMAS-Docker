FROM quay.io/coreos/etcd:v3.5.0

RUN apt update && apt install -y bash openssl

COPY res /res
RUN chmod a+x /res/*.sh
ENTRYPOINT ["/res/entrypoint.sh"]
CMD []
