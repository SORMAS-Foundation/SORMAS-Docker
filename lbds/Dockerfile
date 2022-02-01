FROM openjdk:13

LABEL maintainer="development@crowdcode.io" \
      description="Document Import Service"

ARG LBDS_JAR_FILE_VERSION=1.14.5
ARG CROWDCODE_NEXUS_USER=unknown
ARG CROWDCODE_NEXUS_PASSWORD=unknown

ENV LBDS_JAR_FILE_VERSION=$LBDS_JAR_FILE_VERSION
ENV BACKENDPATH=unknown

# Add a service user to run our application so that it doesn't need to run as root
RUN useradd -ms /bin/bash serviceuser
WORKDIR /home/serviceuser
ADD entrypoint.sh entrypoint.sh

RUN chmod 755 entrypoint.sh && chown serviceuser entrypoint.sh \
  && mkdir -p /home/serviceuser/var/log/payload && chown -R serviceuser /home/serviceuser/var \
  && mkdir /config && chmod 755 /config

RUN yum -y update \
 && yum -y install wget \
 && yum clean all

RUN echo "${CROWDCODE_NEXUS_USER}" && echo "${CROWDCODE_NEXUS_PASSWORD}"

RUN BACKENDPATH=`echo ${LBDS_JAR_FILE_VERSION} | sed "s#-.*#-SNAPSHOT#"` \
 && wget -v -O service-application.jar \
 --user="${CROWDCODE_NEXUS_USER}" \
 --password="${CROWDCODE_NEXUS_PASSWORD}" \
 "https://repo.crowdcode.io/repository/hzi-maven-group/org/hzi/sormas/lbds/lbds-backend/${BACKENDPATH}/lbds-backend-${LBDS_JAR_FILE_VERSION}.jar"

ENV SPRING_OUTPUT_ANSI_ENABLED=ALWAYS \
    JAVA_OPTS="-Xmx512M"

USER serviceuser

EXPOSE 8080

ENTRYPOINT ["./entrypoint.sh"]