#!/bin/sh
set -e

# see man 5 crontab
#
# examples for minutes and hours:
# 0,2,4,6,8,10,12,14,16,18,20,22
# */2
# two times the hour at 15 and 45 min
# MIN="15,45"
# HOUR=
#
# every two hours at 17 min
# MIN="17"
# HOUR="*/2"

RAND=$(( $RANDOM % 19 + 1 ))

MIN=${MIN:-${RAND},$(( ${RAND} + 30 ))}
HOUR=${HOUR:-0,4,7,8,9,10,11,12,13,14,15,16,17,18,20}

cat<<EOF | crontab -
# min     hour      day     month     weekday command
${MIN}    ${HOUR}   *       *         *       /root/pg_dump
EOF

# see: https://github.com/dubiousjim/dcron/issues/13
# ignore using `exec` for `dcron` to get another pid instead of `1`
# exec "$@"
"$@"
