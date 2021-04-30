#!/usr/bin/with-contenv bash

echo "<------------------------------------------------->"
echo
echo "<------------------------------------------------->"
echo "cronjob running on "$(date)
if [ "${DISABLE_CERTBOT}" = true ];then
  echo "Certbot disabled"
  exit 0
fi

. /config/donoteditthisfile.conf


echo "Running certbot renew"
if [ "$ORIGVALIDATION" = "dns" ] || [ "$ORIGVALIDATION" = "duckdns" ]; then
  echo "Running dns validation"
  certbot -n renew \
    --post-hook "if ps aux | grep [n]ginx: > /dev/null; then s6-svc -h /var/run/s6/services/nginx; fi; \
    cd /config/keys/letsencrypt && \
    openssl pkcs12 -export -out privkey.pfx -inkey privkey.pem -in cert.pem -certfile chain.pem -passout pass: && \
    sleep 1 && \
    cat privkey.pem fullchain.pem > priv-fullchain-bundle.pem"
else
  echo "Running http validation"
  certbot -n renew \
    --pre-hook "if ps aux | grep [n]ginx: > /dev/null; then s6-svc -d /var/run/s6/services/nginx; fi" \
    --post-hook "if ps aux | grep 's6-supervise nginx' | grep -v grep > /dev/null; then s6-svc -u /var/run/s6/services/nginx; fi; \
    cd /config/keys/letsencrypt && \
    openssl pkcs12 -export -out privkey.pfx -inkey privkey.pem -in cert.pem -certfile chain.pem -passout pass: && \
    sleep 1 && \
    cat privkey.pem fullchain.pem > priv-fullchain-bundle.pem"
fi