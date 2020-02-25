FROM azul/zulu-openjdk:8

ARG SORMAS_URL

RUN apt-get update \
  && apt-get -y install wget unzip \
  && mkdir -p /root/deploy/sormas\
  && cd /root/deploy/sormas \
  && wget ${SORMAS_URL} -O sormas.zip \
  && unzip sormas.zip
