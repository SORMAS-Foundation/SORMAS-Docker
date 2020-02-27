FROM httpd:2.4-alpine

ARG SORMAS_SERVER_URL

RUN mkdir -p /var/www/ \
  && chown -R www-data:www-data /var/www/ 

COPY ./certs/*.crt /usr/local/apache2/conf/${SORMAS_SERVER_URL}.crt
COPY ./certs/*.key /usr/local/apache2/conf/${SORMAS_SERVER_URL}.key
COPY ./httpd.conf /usr/local/apache2/conf.d/000_${SORMAS_SERVER_URL}.conf
COPY ./ssl_httpd.conf /usr/local/apache2/conf.d/001_ssl_${SORMAS_SERVER_URL}.conf
COPY ./index.html /var/www/index.html

RUN sed -i \
        -e 's/^#\(Include .*httpd-ssl.conf\)/\1/' \
        -e 's/^#\(LoadModule .*mod_ssl.so\)/\1/' \
        -e 's/^#\(LoadModule .*mod_socache_shmcb.so\)/\1/' \
        -e 's/^#\(LoadModule .*mod_rewrite.so\)/\1/' \
        -e 's/^#\(LoadModule .*mod_proxy.so\)/\1/' \
        -e 's/^#\(LoadModule .*mod_proxy_http.so\)/\1/' \
        -e 's/^#\(LoadModule .*mod_ssl.so\)/\1/' \
        conf/httpd.conf

RUN sed -i 's/SORMAS_SERVER_URL/'"${SORMAS_SERVER_URL}"'/g' \
	"/usr/local/apache2/conf.d/000_${SORMAS_SERVER_URL}.conf"

RUN sed -i 's/SORMAS_SERVER_URL/'"${SORMAS_SERVER_URL}"'/g' \
        "/usr/local/apache2/conf.d/001_ssl_${SORMAS_SERVER_URL}.conf"

RUN sed -i '/<VirtualHost _default_/q' /usr/local/apache2/conf/extra/httpd-ssl.conf
RUN sed -i '/<VirtualHost _default_/d' /usr/local/apache2/conf/extra/httpd-ssl.conf

RUN echo "IncludeOptional conf.d/*.conf" >> /usr/local/apache2/conf/httpd.conf \
  && chown -R www-data:www-data /usr/local/apache2/
