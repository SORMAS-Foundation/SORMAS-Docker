FROM httpd:2.4-alpine
ARG SORMAS_SERVER_URL
ENV SORMAS_VERSION=1.37.1

RUN apk add tzdata
RUN mkdir -p /var/log/apache2/ \
  && mkdir /usr/local/apache2/conf.d/ \
  && chown -R www-data:www-data /var/log/apache2/

COPY ./vhost.conf.sh /tmp/vhost.conf.sh
COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf
COPY ./httpd-ssl.conf /usr/local/apache2/conf/extra/httpd-ssl.conf
RUN chmod +x /tmp/vhost.conf.sh


RUN mkdir -p /var/www/sormas/downloads && \
    DEPLOY_PATH=$(mktemp -d) && \
    cd ${DEPLOY_PATH} && \
    wget https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/v${SORMAS_VERSION}/sormas_${SORMAS_VERSION}.zip -O sormas.zip && \
    unzip sormas.zip deploy/android/*  && \
    mv deploy/android/* /var/www/sormas/downloads/ && \
    cd - && \
    rm -rf ${DEPLOY_PATH}


ENTRYPOINT ["/tmp/vhost.conf.sh"]
CMD ["/usr/local/apache2/bin/httpd","-D","FOREGROUND"]
