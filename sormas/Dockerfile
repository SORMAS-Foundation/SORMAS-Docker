FROM azul/zulu-openjdk:8

ARG SORMAS_POSTGRES_PASSWORD
ARG SORMAS_POSTGRES_USER=sormas_user
ARG SORMAS_SERVER_URL
ARG DB_HOST=postgres
ARG DOMAIN_NAME=sormas
ARG DB_NAME=sormas
ARG DB_NAME_AUDIT=sormas_audit
ARG MAIL_HOST=localhost
ARG MAIL_FROM=sormas@localhost
ARG JVM_MAX=4096m

EXPOSE 6080
ENV SORMAS_VERSION=1.33.0
ENV SORMAS_URL=https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/v${SORMAS_VERSION}/sormas_${SORMAS_VERSION}.zip
ENV MAIL_FROM=root@localhost
EXPOSE 6048


RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get -y install wget unzip postgresql curl \
  && apt-get clean

RUN wget -O /tmp/payara-5.192.zip "https://search.maven.org/remotecontent?filepath=fish/payara/distributions/payara/5.192/payara-5.192.zip" \
  && unzip -q -o /tmp/payara-5.192.zip -d /opt/ \
  && rm -R /opt/payara5/glassfish/domains \
  && rm /tmp/payara-5.192.zip

ENV ASENV_PATH="/opt/payara5/glassfish/config/asenv.conf"
RUN useradd payara
COPY setup-server.sh /setup-server.sh
RUN /setup-server.sh
COPY start-server.sh /start-server.sh
CMD ["/start-server.sh"]
