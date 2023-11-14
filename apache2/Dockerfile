FROM httpd:2.4-alpine as build
ARG SORMAS_SERVER_URL

ARG SORMAS_VERSION=1.90.0
ARG MOD_AUTH_OPENIDC_VERSION=2.4.11.3

ENV SORMAS_VERSION=$SORMAS_VERSION
ARG SORMAS_URL=https://github.com/sormas-foundation/SORMAS-Project/releases/download/

RUN apk update --no-cache && \
    apk upgrade --no-cache

RUN apk add --no-cache tzdata openssl curl bash build-base libcrypto3

RUN apk add --no-cache git apache2-dev openssl-dev curl-dev jansson-dev pcre-dev pkgconf wget autoconf automake libtool make g++

RUN apk update --no-cache

RUN mkdir -p /usr/src/cjose && cd /usr/src/cjose
RUN cd /usr/src/cjose && \
  git clone https://github.com/cisco/cjose.git && \
  cd cjose && \
  ./configure CFLAGS="-Wno-error=deprecated-declarations" && make && make install && mkdir -p /tmp && ls -la && cp lib/* /tmp && ls -la /tmp 


RUN mkdir -p /usr/src/apache2 && cd /usr/src/apache2
RUN cd /usr/src/apache2 && wget https://github.com/zmartzone/mod_auth_openidc/archive/refs/tags/v${MOD_AUTH_OPENIDC_VERSION}.tar.gz && tar xzvf v${MOD_AUTH_OPENIDC_VERSION}.tar.gz && cd mod_auth_openidc-${MOD_AUTH_OPENIDC_VERSION}/
RUN cd /usr/src/apache2/mod_auth_openidc-${MOD_AUTH_OPENIDC_VERSION}/ && ls -la && ./autogen.sh && ./configure && make && make install && mkdir -p /tmp && cp .libs/mod_auth_openidc.so /tmp 

  


FROM httpd:2.4-alpine
ARG SORMAS_SERVER_URL
ARG SORMAS_VERSION=1.90.0

ENV SORMAS_VERSION=$SORMAS_VERSION
ARG SORMAS_URL=https://github.com/sormas-foundation/SORMAS-Project/releases/download/

RUN apk update --no-cache && \
    apk upgrade --no-cache && \
    apk add --no-cache --upgrade tzdata jansson pcre hiredis bash curl binutils
RUN mkdir -p /var/log/apache2/ \
  && mkdir /usr/local/apache2/conf.d/ \
  && chown -R www-data:www-data /var/log/apache2/

    
COPY --from=build /tmp/libcjose.so.0.0.0 .
COPY --from=build /tmp/libcjose.lai .
COPY --from=build /tmp/libcjose.a .
RUN /usr/bin/install -c libcjose.so.0.0.0 /usr/local/lib/libcjose.so.0.0.0 && \
  (cd /usr/local/lib && { ln -s -f libcjose.so.0.0.0 libcjose.so.0 || { rm -f libcjose.so.0 && ln -s libcjose.so.0.0.0 libcjose.so.0; }; }) && \
  (cd /usr/local/lib && { ln -s -f libcjose.so.0.0.0 libcjose.so || { rm -f libcjose.so && ln -s libcjose.so.0.0.0 libcjose.so; }; }) && \
  /usr/bin/install -c libcjose.lai /usr/local/lib/libcjose.la && \
  /usr/bin/install -c libcjose.a /usr/local/lib/libcjose.a && \
  chmod 644 /usr/local/lib/libcjose.a && \
  ranlib /usr/local/lib/libcjose.a && \
  PATH="/usr/local/apache2/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/sbin" ldconfig -n /usr/local/lib
  
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
