FROM hzibraunschweig/sormas-rscript:3.5-5.2021.10

ARG SORMAS_POSTGRES_PASSWORD=password
ARG SORMAS_POSTGRES_USER=sormas_user
ARG SORMAS_SERVER_URL=sormas-docker-test.com
ARG DB_JDBC_MAXPOOLSIZE=128
ARG DB_HOST=postgres
ARG DOMAIN_NAME=sormas
ARG DB_NAME=sormas
ARG DB_NAME_AUDIT=sormas_audit
ARG MAIL_HOST=localhost
ARG MAIL_FROM=sormas@localhost
ARG JVM_MAX=4096m
ARG SORMAS_URL=https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/
EXPOSE 6080

ARG SORMAS_VERSION=1.73.0

ENV SORMAS_VERSION=$SORMAS_VERSION

ENV MAIL_FROM=root@localhost
ENV DEBIAN_FRONTEND=noninteractive
EXPOSE 6048



ENV ASENV_PATH="/opt/payara5/glassfish/config/asenv.conf"
RUN useradd payara

COPY setup-server.sh /setup-server.sh

RUN chmod +x /setup-server.sh
RUN /setup-server.sh
COPY start-server.sh /start-server.sh
RUN chmod +x /start-server.sh

COPY glowroot-0.13.6-dist.zip /opt
COPY admin.json /opt

RUN cd /opt \
  && apt-get -y install unzip \
  && unzip glowroot-0.13.6-dist.zip \
  && mv /opt/admin.json /opt/glowroot/admin.json


CMD ["/start-server.sh"]
