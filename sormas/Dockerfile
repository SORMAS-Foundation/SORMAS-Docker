FROM hzibraunschweig/sormas-rscript:3.5-5.2020.2

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


ARG SORMAS_VERSION=1.59.2

ENV SORMAS_VERSION=$SORMAS_VERSION

ENV MAIL_FROM=root@localhost
ENV DEBIAN_FRONTEND=noninteractive
EXPOSE 6048



ENV ASENV_PATH="/opt/payara5/glassfish/config/asenv.conf"
RUN useradd payara

COPY setup-server.sh /setup-server.sh
COPY s2s-generate-cert.sh /opt/sormas/s2s-generate-cert.sh
RUN chmod +x /opt/sormas/s2s-generate-cert.sh
COPY s2s-import-to-truststore.sh /opt/sormas/s2s-import-to-truststore.sh
RUN chmod +x /opt/sormas/s2s-import-to-truststore.sh


RUN chmod +x /setup-server.sh
RUN /setup-server.sh
COPY start-server.sh /start-server.sh
RUN chmod +x /start-server.sh
CMD ["/start-server.sh"]
