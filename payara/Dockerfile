FROM azul/zulu-openjdk:11
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get -y install wget unzip postgresql vim curl --no-install-recommends\
  && apt-get clean

RUN wget --no-check-certificate -O /tmp/payara-5.2021.10.zip "https://search.maven.org/remotecontent?filepath=fish/payara/distributions/payara/5.2021.10/payara-5.2021.10.zip" \
  && unzip -q -o /tmp/payara-5.2021.10.zip -d /opt/ \
  && rm -R /opt/payara5/glassfish/domains \
  && rm /tmp/payara-5.2021.10.zip

# remove this below patch after upgraded Payara to higher than 5.2021.10 once (No valid EE environment) is FIXED
RUN wget --no-check-certificate -O /opt/payara5/glassfish/modules/weld-integration.jar "https://raw.githubusercontent.com/hzi-braunschweig/SORMAS-Project/development/sormas-base/setup/glassfish-modules/weld-integration.jar"
