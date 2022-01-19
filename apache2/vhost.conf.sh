#!/bin/bash

cat << EOF > /usr/local/apache2/conf.d/000_${SORMAS_SERVER_URL}.conf
<VirtualHost *:80>
    ServerName ${SORMAS_SERVER_URL}
    <IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{HTTPS} !=on
    RewriteRule ^/(.*) https://${SORMAS_SERVER_URL}/$REQUEST_URI [R,L]
   </IfModule>
   <IfModule !mod_rewrite.c>
   	Redirect 301 /$REQUEST_URI https://${SORMAS_SERVER_URL}/$REQUEST_URI
   </IfModule>
</VirtualHost>
EOF

cat << EOF > /usr/local/apache2/conf.d/001_ssl_${SORMAS_SERVER_URL}.conf
Listen 443
<VirtualHost *:443>
        ServerName ${SORMAS_SERVER_URL}
        # RedirectMatch: All locations not listed here will be redirected to sormas-ui
        # APACHE_REDIRECT_EXCLUDE Example Usage: "|test|test2" will add /test and /test2 to that list
        # IMPORTANT: it needs to start with "|"
	      RedirectMatch "^(/(?!downloads|keycloak|metrics${APACHE_REDIRECT_EXCLUDE}).*)" https://${SORMAS_SERVER_URL}/sormas-ui\$1

        ErrorLog /var/log/apache2/error.log
        LogLevel warn
        LogFormat "%h %l %u %t \"%r\" %>s %b _%D_ \"%{User}i\"  \"%{Connection}i\"  \"%{Referer}i\" \"%{User-agent}i\"" combined_ext
        CustomLog /var/log/apache2/access.log combined_ext

        SSLEngine on
        SSLCertificateFile    /usr/local/apache2/certs/${SORMAS_SERVER_URL}.crt
        SSLCertificateKeyFile /usr/local/apache2/certs/${SORMAS_SERVER_URL}.key
        #SSLCertificateChainFile /etc/ssl/certs/${SORMAS_SEVER_URL}.ca-bundle

        # disable weak ciphers and old TLS/SSL
        SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
        SSLCipherSuite TLS_AES_256_GCM_SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305
	      SSLHonorCipherOrder on
        #SSLCompression off

        ProxyRequests Off
        ProxyPreserveHost On
        ProxyPass /sormas-ui http://sormas:6080/sormas-ui connectiontimeout=5 timeout=1800
        ProxyPassReverse /sormas-ui http://sormas:6080/sormas-ui
        ProxyPass /sormas-rest http://sormas:6080/sormas-rest connectiontimeout=5 timeout=1800
        ProxyPassReverse /sormas-rest http://sormas:6080/sormas-rest
        ProxyPass /keycloak http://keycloak:8080/keycloak connectiontimeout=5 timeout=600
        ProxyPassReverse /keycloak http://keycloak:8080/keycloak
	      ProxyPass /sormas-angular http://sormas-angular:80/ connectiontimeout=5 timeout=600
        ProxyPassReverse /sormas-angular/ http://sormas-angular:80/
        <Location /metrics>
            ProxyPass  http://sormas:6080/metrics connectiontimeout=5 timeout=600
            ProxyPassReverse http://sormas:6080/metrics
            Order deny,allow
            Deny from all
            Allow from ${PROMETHEUS_SERVERS}
        </Location>

        RequestHeader set X-Forwarded-Proto https

        Options -Indexes
        AliasMatch "/downloads/sormas-(.*)" "/var/www/sormas/downloads/sormas-\$1"

        Alias "/downloads" "/var/www/sormas/downloads/"

        <Directory "/var/www/sormas/downloads/">
            Require all granted
            Options +Indexes
        </Directory>

        <IfModule mod_deflate.c>
            AddOutputFilterByType DEFLATE text/plain text/html text/xml
            AddOutputFilterByType DEFLATE text/css text/javascript
            AddOutputFilterByType DEFLATE application/json
            AddOutputFilterByType DEFLATE application/xml application/xhtml+xml
            AddOutputFilterByType DEFLATE application/javascript application/x-javascript
            DeflateCompressionLevel 1
        </IfModule>
        # Includes all files with the .conf ending in the conf.d/001_ssl_includes/ Directory
        # IMPORTANT: if you include a location you need to add it to the APACHE_REDIRECT_EXCLUDE variable 
        IncludeOptional conf.d/001_ssl_includes/*.conf
</VirtualHost>
EOF
exec $@
