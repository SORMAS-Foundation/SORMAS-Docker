FROM httpd:2.4-alpine as build
ARG SORMAS_SERVER_URL

ARG SORMAS_VERSION=1.75.2
ARG MOD_AUTH_OPENIDC_VERSION=2.4.11.3

ENV SORMAS_VERSION=$SORMAS_VERSION
ARG SORMAS_URL=https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/

RUN echo "http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories 
RUN echo "http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories 
RUN echo "http://nl.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

RUN apk update --no-cache && \
    apk upgrade --no-cache && \
    apk add --no-cache --upgrade tzdata openssl curl bash
RUN mkdir -p /var/log/apache2/ \
  && mkdir /usr/local/apache2/conf.d/ \
  && chown -R www-data:www-data /var/log/apache2/

RUN apk add git apache2-dev cjose-dev openssl-dev curl-dev jansson-dev pcre-dev pkgconf wget autoconf automake libtool make g++
RUN mkdir -p /usr/src/apache2 && cd /usr/src/apache2
RUN cd /usr/src/apache2 && wget https://github.com/zmartzone/mod_auth_openidc/archive/refs/tags/v${MOD_AUTH_OPENIDC_VERSION}.tar.gz && tar xzvf v${MOD_AUTH_OPENIDC_VERSION}.tar.gz && cd mod_auth_openidc-${MOD_AUTH_OPENIDC_VERSION}/
RUN cd /usr/src/apache2/mod_auth_openidc-${MOD_AUTH_OPENIDC_VERSION}/ && ls -la &&  bash ./autogen.sh && bash ./configure && make && mkdir -p /tmp && cp .libs/mod_auth_openidc.so /tmp




FROM httpd:2.4-alpine
ARG SORMAS_SERVER_URL

ARG SORMAS_VERSION=1.75.2

ENV SORMAS_VERSION=$SORMAS_VERSION
ARG SORMAS_URL=https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/

RUN apk update --no-cache && \
    apk upgrade --no-cache && \
    apk add --no-cache --upgrade tzdata jansson pcre hiredis bash
RUN mkdir -p /var/log/apache2/ \
  && mkdir /usr/local/apache2/conf.d/ \
  && chown -R www-data:www-data /var/log/apache2/

RUN echo "http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories 
RUN echo "http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories 
RUN echo "http://nl.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

RUN apk update && \
    apk add \
    cjose \
    cjose-dev 
     

COPY --from=build /tmp/mod_auth_openidc.so .
RUN /usr/bin/install -c -d /usr/lib/apache2 && \
  /usr/bin/install -c -p -m 755 ./mod_auth_openidc.so /usr/lib/apache2/mod_auth_openidc.so

   
COPY ./vhost.conf.sh /tmp/vhost.conf.sh
COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf
COPY ./httpd-ssl.conf /usr/local/apache2/conf/extra/httpd-ssl.conf
RUN chmod +x /tmp/vhost.conf.sh

RUN ls -la /tmp

RUN mkdir -p /var/www/sormas/downloads && \
    DEPLOY_PATH=$(mktemp -d) && \
    cd ${DEPLOY_PATH} && \
    wget ${SORMAS_URL}v${SORMAS_VERSION}/sormas_${SORMAS_VERSION}.zip -O sormas.zip && \
    unzip sormas.zip deploy/android/*  && \
    mv deploy/android/* /var/www/sormas/downloads/ && \
    cd - && \
    rm -rf ${DEPLOY_PATH}


ENTRYPOINT ["/tmp/vhost.conf.sh"]
CMD ["/usr/local/apache2/bin/httpd","-D","FOREGROUND"]
