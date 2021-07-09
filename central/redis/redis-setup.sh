redis-server /usr/local/etc/redis/config/redis.conf --daemonize yes --tls-auth-clients no && sleep 1

redis-cli --user default --tls --cacert /srv/tls/ca/public/ca.crt  < /srv/fixtures/s2s-access-data.redis || exit 1
redis-cli --user default --tls --cacert /srv/tls/ca/public/ca.crt save || exit 1
redis-cli --user default --tls --cacert /srv/tls/ca/public/ca.crt shutdown || exit 1


redis-server /usr/local/etc/redis/config/redis.conf
