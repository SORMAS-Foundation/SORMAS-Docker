#!/bin/bash

cat << EOF > /usr/local/apache2/conf.d/000_${SORMAS_SERVER_URL}.conf
<VirtualHost *:80>
    ServerName ${SORMAS_SERVER_URL}
    <IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{HTTPS} !=on
    RewriteRule ^/(.*) https://${SORMAS_SERVER_URL}/$1 [R,L]
   </IfModule>
   <IfModule !mod_rewrite.c>
   	Redirect 301 / https://${SORMAS_SERVER_URL}/
   </IfModule>
</VirtualHost>
EOF
