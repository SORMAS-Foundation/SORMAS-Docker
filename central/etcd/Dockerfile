FROM quay.io/coreos/etcd:v3.5.0

RUN apt update && apt upgrade -y
RUN apt install bash procps -y

RUN mkdir /srv/fixtures/
COPY setup_and_run.sh /srv

RUN mkdir /srv/certs/
CMD /srv/setup_and_run.sh