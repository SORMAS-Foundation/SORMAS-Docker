ARG KEYCLOAK_VERSION=21.1.2

# 1. Get config data from SORMAS release archive
FROM redhat/ubi8-minimal:latest as config-source
USER root
RUN microdnf update && microdnf install -y wget unzip

ARG SORMAS_URL=https://github.com/sormas-foundation/SORMAS-Project/releases/download/
ARG SORMAS_VERSION=1.96.0

RUN cd /tmp && \
    wget ${SORMAS_URL}v${SORMAS_VERSION}/sormas_${SORMAS_VERSION}.zip -O sormas.zip && \
    unzip sormas.zip

# 2. Configure keycloak
# when updating keycloak version check https://www.keycloak.org/docs/latest/upgrading/index.html#migration-changes
# also make sure to update the keycloak dependency in SORMAS-Project
ARG KEYCLOAK_VERSION
FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION} as kc-builder
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
ARG KEYCLOAK_VERSION
FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}

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