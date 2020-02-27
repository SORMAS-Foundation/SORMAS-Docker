FROM httpd:2.4-alpine

ARG SORMAS_SERVER_URL

RUN mkdir -p /var/www/ \
  && chown -R www-data:www-data /var/www/ 

COPY ./certs/*.crt /usr/local/apache2/conf/${SORMAS_SERVER_URL}.crt
COPY ./certs/*.key /usr/local/apache2/conf/${SORMAS_SERVER_URL}.key
COPY ./vhost.conf.sh /tmp/vhost.conf.sh
COPY ./vhost_ssl.conf.sh /tmp/vhost_ssl.conf.sh
COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf
COPY ./httpd-ssl.conf /usr/local/apache2/conf/extra/httpd-ssl.conf
COPY ./index.html /var/www/index.html

RUN sed -i 's/SORMAS_SERVER_URL/'"${SORMAS_SERVER_URL}"'/g' \
	"/usr/local/apache2/conf.d/000_${SORMAS_SERVER_URL}.conf"

RUN sed -i 's/SORMAS_SERVER_URL/'"${SORMAS_SERVER_URL}"'/g' \
        "/usr/local/apache2/conf.d/001_ssl_${SORMAS_SERVER_URL}.conf"

RUN sed -i '/<VirtualHost _default_/q' /usr/local/apache2/conf/extra/httpd-ssl.conf
RUN sed -i '/<VirtualHost _default_/d' /usr/local/apache2/conf/extra/httpd-ssl.conf

RUN echo "IncludeOptional conf.d/*.conf" >> /usr/local/apache2/conf/httpd.conf \
  && chown -R www-data:www-data /usr/local/apache2/
