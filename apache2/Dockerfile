FROM httpd:2.4-alpine

ARG SORMAS_SERVER_URL

RUN mkdir -p /var/www/ \
  && mkdir -p /var/log/apache2/ \
  && mkdir /usr/local/apache2/conf.d/ \
  && chown -R www-data:www-data /var/log/apache2/

COPY ./vhost.conf.sh /tmp/vhost.conf.sh
COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf
COPY ./httpd-ssl.conf /usr/local/apache2/conf/extra/httpd-ssl.conf
COPY ./index.html /var/www/index.html
#COPY ./certs/sormas-docker-test.com.crt /usr/local/apache2/conf/sormas-docker-test.com.crt
#COPY ./certs/sormas-docker-test.com.key /usr/local/apache2/conf/sormas-docker-test.com.key
RUN chown -R www-data:www-data /var/www \
  && chown -R www-data:www-data /etc/ssl/certs/ 

ENTRYPOINT ["/tmp/vhost.conf.sh"]
CMD ["/usr/local/apache2/bin/httpd","-D","FOREGROUND"]
