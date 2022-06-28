FROM jboss/keycloak:16.1.1

ARG SORMAS_URL=https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/

ARG SORMAS_VERSION=1.73.0

ARG SORMAS_SERVER_URL=sormas-docker-test.com
ARG KEYCLOAK_SORMAS_REST_SECRET=changeit
ARG KEYCLOAK_SORMAS_UI_SECRET=changeit
ARG KEYCLOAK_SORMAS_BACKEND_SECRET=changeit

RUN sed -i -e 's/<web-context>auth<\/web-context>/<web-context>keycloak\/auth<\/web-context>/' $JBOSS_HOME/standalone/configuration/standalone.xml
RUN sed -i -e 's/<web-context>auth<\/web-context>/<web-context>keycloak\/auth<\/web-context>/' /opt/jboss/keycloak/standalone/configuration/standalone-ha.xml
RUN sed -i -e 's/name="\/"/name="\/keycloak\/"/' $JBOSS_HOME/standalone/configuration/standalone.xml
RUN sed -i -e 's/name="\/"/name="\/keycloak\/"/' $JBOSS_HOME/standalone/configuration/standalone-ha.xml
RUN sed -i -e 's/\/auth/\/keycloak\/auth"/' $JBOSS_HOME/welcome-content/index.html

COPY setup-keycloak.sh /opt/jboss/startup-scripts/
COPY update-realm.sh $JBOSS_HOME
COPY standalone-logging.cli /opt/jboss/startup-scripts/

USER root
RUN chown jboss /opt/jboss/startup-scripts/setup-keycloak.sh && \
    chown jboss /opt/jboss/startup-scripts/standalone-logging.cli && \
    chmod +x /opt/jboss/startup-scripts/setup-keycloak.sh && \
    chmod +x /opt/jboss/startup-scripts/standalone-logging.cli

RUN chown jboss $JBOSS_HOME/update-realm.sh && \
  chmod +x $JBOSS_HOME/update-realm.sh

RUN microdnf install wget
RUN microdnf install unzip

RUN TEMP_PATH=$(mktemp -d) && \
    cd ${TEMP_PATH} && \
    wget ${SORMAS_URL}v${SORMAS_VERSION}/sormas_${SORMAS_VERSION}.zip -O sormas.zip && \
    unzip sormas.zip deploy/keycloak/*  && \
    mv deploy/keycloak/themes/* $JBOSS_HOME/themes && \
    mv deploy/keycloak/SORMAS.json $JBOSS_HOME/SORMAS.json && \
    mv deploy/keycloak/*.jar $JBOSS_HOME/standalone/deployments && \
    rm -rf ${TEMP_PATH}
USER 1000

ENV KEYCLOAK_IMPORT $JBOSS_HOME/SORMAS.json
ENV KEYCLOAK_MIGRATION_STRATEGY IGNORE_EXISTING

EXPOSE 8080
EXPOSE 8443
