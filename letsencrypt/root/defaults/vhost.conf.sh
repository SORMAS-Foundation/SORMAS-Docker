#!/bin/bash

cat << EOF > /config/nginx/proxy-confs/vhost.conf
server {
    listen 80;
    server_name ${URL};
    return 301 https://\$host\$request_uri;
}

server {
    listen 80;
    listen 443 ssl;
    server_name *.${URL};
    return 301 https://${URL}\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${URL};

    ssl_certificate           /etc/letsencrypt/live/${URL}/fullchain.pem;
    ssl_certificate_key        /etc/letsencrypt/live/${URL}/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    proxy_hide_header X-Powered-By;
    proxy_cookie_domain ~(?P<secure_domain>([-0-9a-z]+\.)?[-0-9a-z]+\.[a-z]+)$ "\$secure_domain; secure";

    add_header Public-Key-Pins 'pin-sha256="sRHdihwgkaib1P1gxX8HFszlD+7/gTfNvuAybgLPNis="; pin-sha256="YLh1dUR9y6Kja30RrAn7JKnbQG/uEtLMkBgFF2Fuihg="; pin-sha256="C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=^C  max-age=60;';
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy no-referrer;
    add_header X-Content-Type-Options nosniff;

    access_log  /config/log/nginx/access.log;
    error_log   /config/log/nginx/error.log crit;

    location ~ "^(/(?!(downloads|sormas-ui|sormas-rest|metrics)).*)" {
        rewrite ^(.*)$ https://${URL}/sormas-ui\\\$1 redirect;
    }

    location /sormas-ui {
        proxy_pass http://sormas:6080/sormas-ui;
        proxy_read_timeout ${HTTP_TIMEOUT}s;
        proxy_set_header X-Forwarded-Host \$host:\$server_port;
        proxy_set_header X-Forwarded-Server \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /sormas-rest {
        proxy_pass http://sormas:6080/sormas-rest;
        proxy_read_timeout ${HTTP_TIMEOUT}s;
        proxy_set_header X-Forwarded-Host \$host:\$server_port;
        proxy_set_header X-Forwarded-Server \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /metrics {
        $(for server in ${PROMETHEUS_SERVERS}
        do
          echo "allow $server;"
        done)
        deny all;
        proxy_pass http://sormas:6080/metrics;
        proxy_read_timeout ${HTTP_TIMEOUT}s;
        proxy_set_header X-Forwarded-Host \$host:\$server_port;
        proxy_set_header X-Forwarded-Server \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /downloads {
        root /config/www/sormas/;
        autoindex on;
    }
}
EOF