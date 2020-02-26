FROM azul/zulu-openjdk:8

ARG SORMAS_URL
ARG SORMAS_POSTGRES_USER
ARG SORMAS_POSTGRES_PASSWORD
ARG MAIL_FROM
RUN apt-get update \
  && apt-get -y install wget unzip postgresql curl \
  && mkdir -p /root/deploy/sormas\
  && cd /root/deploy/sormas \
  && wget ${SORMAS_URL} -O sormas.zip \
  && unzip sormas.zip
RUN mkdir -p /opt/sormas/temp \
  && mkdir -p /opt/sormas/generated \
  && mkdir -p /opt/sormas/custom \
  && mkdir -p /opt/payara5 \
  && mkdir -p /opt/domains \
  && mkdir -p /var/www/sormas/downloads

RUN wget -O /opt/payara5/payara-5.192.zip "https://search.maven.org/remotecontent?filepath=fish/payara/distributions/payara/5.192/payara-5.192.zip" \
  && unzip -q -o /opt/payara5/payara-5.192.zip -d /opt/payara5 \
  && mv /opt/payara5/payara5/* /opt/payara5 \
  && rm -R /opt/payara5/payara5 \
  && rm -R /opt/payara5/glassfish/domains

ENV ASENV_PATH="/opt/payara5/glassfish/config/asenv.conf"

COPY start-server.sh /root/deploy/sormas/deploy/start-server.sh
RUN chmod +x /root/deploy/sormas/deploy/start-server.sh
EXPOSE 6048
EXPOSE 6080
EXPOSE 6081
ARG MAIL_FROM
ENV PGPASSWORD="password"
ENTRYPOINT ["/bin/sh","/root/deploy/sormas/deploy/start-server.sh" ]
