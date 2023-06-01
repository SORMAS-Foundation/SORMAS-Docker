FROM azul/zulu-openjdk:11
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get -y install wget unzip postgresql vim curl --no-install-recommends\
  && apt-get clean

RUN wget --no-check-certificate -O /tmp/payara-5.2022.5.zip "https://search.maven.org/remotecontent?filepath=fish/payara/distributions/payara/5.2022.5/payara-5.2022.5.zip" \
  && unzip -q -o /tmp/payara-5.2022.5.zip -d /opt/ \
  && rm -R /opt/payara5/glassfish/domains \
  && rm /tmp/payara-5.2022.5.zip
