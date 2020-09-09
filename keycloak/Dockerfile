FROM jboss/keycloak:11.0.0

ARG SORMAS_SERVER_URL=sormas-docker-test.com
ARG KEYCLOAK_SORMAS_REST_SECRET=changeit
ARG KEYCLOAK_SORMAS_UI_SECRET=changeit
ARG KEYCLOAK_SORMAS_BACKEND_SECRET=changeit

RUN sed -i -e 's/<web-context>auth<\/web-context>/<web-context>keycloak\/auth<\/web-context>/' $JBOSS_HOME/standalone/configuration/standalone.xml
RUN sed -i -e 's/<web-context>auth<\/web-context>/<web-context>keycloak\/auth<\/web-context>/' /opt/jboss/keycloak/standalone/configuration/standalone-ha.xml
RUN sed -i -e 's/name="\/"/name="\/keycloak\/"/' $JBOSS_HOME/standalone/configuration/standalone.xml
RUN sed -i -e 's/name="\/"/name="\/keycloak\/"/' $JBOSS_HOME/standalone/configuration/standalone-ha.xml
RUN sed -i -e 's/\/auth/\/keycloak\/auth"/' $JBOSS_HOME/welcome-content/index.html

ADD themes $JBOSS_HOME/themes

COPY SORMAS.json $JBOSS_HOME/SORMAS.json
COPY setup-keycloak.sh /opt/jboss/startup-scripts/
RUN chown jboss /opt/jboss/startup-scripts/setup-keycloak.sh && \
  chmod +x /opt/jboss/startup-scripts/setup-keycloak.sh

ENV KEYCLOAK_IMPORT $JBOSS_HOME/SORMAS.json
ENV KEYCLOAK_MIGRATION_STRATEGY IGNORE_EXISTING

EXPOSE 8080
EXPOSE 8443
