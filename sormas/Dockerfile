FROM azul/zulu-openjdk:8
EXPOSE 6080
ARG SORMAS_URL
ENV SORMAS_POSTGRES_USER=sormas_user

ENV SORMAS_POSTGRES_PASSWORD=password
ENV MAIL_FROM=root@localhost
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get -y install wget unzip postgresql curl \
  && apt-get clean \
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
RUN useradd payara
COPY start-server.sh /root/deploy/sormas/deploy/start-server.sh
COPY server-update.sh /root/deploy/sormas/deploy/update-server.sh
RUN chmod +x /root/deploy/sormas/deploy/start-server.sh

ENTRYPOINT ["/bin/sh","/root/deploy/sormas/deploy/start-server.sh" ]
