# 1. Get config data from SORMAS release archive
FROM redhat/ubi8-minimal:latest as config-source
USER root
RUN microdnf update && microdnf install -y wget unzip curl

ARG SORMAS_URL=https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/
ARG SORMAS_VERSION=1.80.0

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
RUN bin/kc.sh build --db postgres --spi-password-hashing-sormas-sha256-enabled=true  \
    --health-enabled=true

# 3. Runtime container
FROM quay.io/keycloak/keycloak:21.0.1

COPY --from=kc-builder /opt/keycloak/ /opt/keycloak/
WORKDIR /opt/keycloak
RUN yum update && yum install -y curl

# --import-realm imports all realm JSON files provided in data/import https://www.keycloak.org/server/containers#_importing_a_realm_on_startup
# --hostname-strict-https b/c of keycloak/keycloak#11922
# --http-enabled / --proxy for HTTP between reverse proxy and the container
# --http-relative-path to register the reverse proxy path
ENTRYPOINT ["bin/kc.sh", "start", "--import-realm", \
    "--hostname-strict-https=false", "--http-enabled=true", "--proxy=edge", "--http-relative-path=/keycloak", \
    "--log-level=INFO,org.keycloak.events:DEBUG"]
