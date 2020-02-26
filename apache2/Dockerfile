FROM centos:centos8

ARG SORMAS_SERVER_URL

RUN yum install httpd mod_ssl -y
RUN mkdir -p /var/www/ \
  && chown -R apache:apache /var/www/ \
  && mkdir /etc/httpd/sites-available/ \
  && mkdir /etc/httpd/sites-enabled/ \
  && chown -R apache:apache /etc/httpd/

COPY ./certs/*.crt /etc/httpd/conf/${SORMAS_SERVER_URL}.crt
COPY ./certs/*.key /etc/httpd/conf/${SORMAS_SERVER_URL}.key
COPY ./httpd.conf /etc/httpd/conf.d/000_${SORMAS_SERVER_URL}.conf
COPY ./ssl_httpd.conf /etc/httpd/conf.d/001_ssl_${SORMAS_SERVER_URL}.conf
COPY ./index.html /var/www/index.html

RUN sed -i \
        -e 's/^#\(Include .*httpd-ssl.conf\)/\1/' \
        -e 's/^#\(LoadModule .*mod_ssl.so\)/\1/' \
        -e 's/^#\(LoadModule .*mod_socache_shmcb.so\)/\1/' \
        -e 's/^#\(LoadModule .*mod_rewrite.so\)/\1/' \
        -e 's/^#\(LoadModule .*mod_proxy.so\)/\1/' \
        -e 's/^#\(LoadModule .*mod_proxy_http.so\)/\1/' \
        -e 's/^#\(LoadModule .*mod_ssl.so\)/\1/' \
        /etc/httpd/conf/httpd.conf

RUN sed -i 's/SORMAS_SERVER_URL/'"${SORMAS_SERVER_URL}"'/g' \
	"/etc/httpd/conf.d/000_${SORMAS_SERVER_URL}.conf"

RUN sed -i 's/SORMAS_SERVER_URL/'"${SORMAS_SERVER_URL}"'/g' \
        "/etc/httpd/conf.d/001_ssl_${SORMAS_SERVER_URL}.conf"

RUN sed -i '/<VirtualHost _default_/q' /etc/httpd/conf.d/ssl.conf
RUN sed -i '/<VirtualHost _default_/d' /etc/httpd/conf.d/ssl.conf

ENTRYPOINT ["/usr/sbin/httpd", "-D", "FOREGROUND"]