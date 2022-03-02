FROM quay.io/coreos/etcd:v3.5.0

RUN apt update && apt install -y bash openssl

COPY etcd.yml /etc/etcd/etcd.yml
RUN \
mkdir /certs &&\
openssl req -new -text -passout pass:abcd -subj /CN=secured_etcd -out /certs/server.req -keyout /certs/privkey.pem &&\
openssl rsa -in /certs/privkey.pem -passin pass:abcd -out /certs/server.key &&\
openssl req -x509 -in /certs/server.req -text -key /certs/server.key -out /certs/server.crt

COPY entrypoint.sh /entrypoint.sh
COPY init.sh /init.sh
ENTRYPOINT /entrypoint.sh
CMD /usr/local/bin/etcd
