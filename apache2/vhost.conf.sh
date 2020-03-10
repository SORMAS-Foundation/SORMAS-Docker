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

	RedirectMatch "^(/(?!downloads).*)" https://${SORMAS_SERVER_URL}/sormas-ui/$1
	
        ErrorLog /usr/local/apache2/error.log
        LogLevel warn
        LogFormat "%h %l %u %t \"%r\" %>s %b _%D_ \"%{User}i\"  \"%{Connection}i\"  \"%{Referer}i\" \"%{User-agent}i\"" combined_ext
        CustomLog /var/log/apache2/access.log combined_ext        

        SSLEngine on
        SSLCertificateFile    /usr/local/apache2/certs/${SORMAS_SERVER_URL}.crt
        SSLCertificateKeyFile /usr/local/apache2/certs/${SORMAS_SERVER_URL}.key
        #SSLCertificateChainFile /etc/ssl/certs/${SORMAS_SEVER_URL}.ca-bundle

        # disable weak ciphers and old TLS/SSL
        SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
	SSLCipherSuite HIGH:MEDIUM:!aNULL:!MD5
        #SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE$
        SSLHonorCipherOrder off

	
        ProxyRequests Off
        ProxyPreserveHost On
        ProxyPass /sormas-ui http://sormas:6080/sormas-ui
        ProxyPassReverse /sormas-ui http://sormas:6080/sormas-ui
        ProxyPass /sormas-rest http://sormas:6080/sormas-rest
        ProxyPassReverse /sormas-rest http://sormas:6080/sormas-rest

        Options -Indexes
        AliasMatch "/downloads/sormas-(.*)" "/var/www/sormas/downloads/sormas-$1"

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
</VirtualHost>
EOF
exec $@
