FROM azul/zulu-openjdk:8u202-8.36.0.1
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get -y install wget unzip postgresql --no-install-recommends\
  && apt-get clean

RUN wget --no-check-certificate -O /tmp/payara-5.192.zip "https://search.maven.org/remotecontent?filepath=fish/payara/distributions/payara/5.192/payara-5.192.zip" \
  && unzip -q -o /tmp/payara-5.192.zip -d /opt/ \
  && rm -R /opt/payara5/glassfish/domains \
  && rm /tmp/payara-5.192.zip
