# 1. Get config data from SORMAS release archive
FROM redhat/ubi8-minimal:latest as config-source
USER root
RUN microdnf update && microdnf install -y wget unzip

ARG SORMAS_URL=https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/
ARG SORMAS_VERSION=1.83.1

RUN cd /tmp && \
    wget ${SORMAS_URL}v${SORMAS_VERSION}/sormas_${SORMAS_VERSION}.zip -O sormas.zip && \
    unzip sormas.zip

# 2. Configure keycloak
FROM quay.io/keycloak/keycloak:21.0.1 as kc-builder
WORKDIR /opt/keycloak

USER root
COPY --from=config-source /tmp/deploy/keycloak /tmp/deploy/keycloak
RUN chown -R -c keycloak /tmp/deploy/keycloak
USER keycloak

RUN mv /tmp/deploy/keycloak/themes/* themes/

RUN mkdir "data/import" && \
    mv /tmp/deploy/keycloak/SORMAS.json data/import/ && \
    mv /tmp/deploy/keycloak/*.jar providers/

# Optimize startup by building once
# https://www.keycloak.org/server/configuration#_optimize_the_keycloak_startup
# --http-relative-path to register the reverse proxy path
# Addtional settings are done when starting the keycloak in /start-keycloak.sh
RUN bin/kc.sh build --db postgres --spi-password-hashing-sormas-sha256-enabled=true  \
    --http-relative-path=/keycloak --health-enabled=true --metrics-enabled=true

# 3. Runtime container
FROM quay.io/keycloak/keycloak:21.0.1

USER root
COPY start-keycloak.sh /start-keycloak.sh
COPY update-realm.sh /update-realm.sh
COPY --from=kc-builder /opt/keycloak/ /opt/keycloak/
RUN chown keycloak /start-keycloak.sh \
  && chown keycloak /update-realm.sh \
  &&  chmod ug+x /start-keycloak.sh \
  && chmod ug+x /update-realm.sh
USER keycloak
WORKDIR /opt/keycloak

ENTRYPOINT ["/start-keycloak.sh"]