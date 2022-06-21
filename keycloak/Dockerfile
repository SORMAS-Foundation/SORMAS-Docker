# Keycloak builder
FROM quay.io/keycloak/keycloak:18.0.1 as kc-builder
USER root
RUN microdnf update && microdnf install wget unzip
USER keycloak
WORKDIR /opt/keycloak

ARG SORMAS_URL=https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/
ARG SORMAS_VERSION=1.72.1

RUN cd /tmp && \
    wget ${SORMAS_URL}v${SORMAS_VERSION}/sormas_${SORMAS_VERSION}.zip -O sormas.zip && \
    unzip sormas.zip

RUN mv /tmp/deploy/keycloak/themes/* themes/

RUN mkdir "data/import" && \
    mv /tmp/deploy/keycloak/SORMAS.json data/import/ && \
    mv /tmp/deploy/keycloak/*.jar providers/

RUN bin/kc.sh build --http-relative-path=keycloak --db postgres --spi-password-hashing-sormas-sha256-enabled=true

# Runtime container
FROM quay.io/keycloak/keycloak:18.0.1



COPY --from=kc-builder /opt/keycloak/ /opt/keycloak/
WORKDIR /opt/keycloak

ENTRYPOINT ["bin/kc.sh", "start", "--proxy=edge", "--http-enabled=true", "--hostname-strict-https=false", "--import-realm", \
 "--log-level=INFO,org.keycloak.events:DEBUG"]
