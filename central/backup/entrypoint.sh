#!/bin/sh

# This section provides MIN in range of "1-20,31-59", e.g. MIN=5,35
RAND=$(( $RANDOM % 19 + 1 ))
MIN=${MIN:-${RAND},$(( ${RAND} + 30 ))}
HOUR=${HOUR:-0,4,7,8,9,10,11,12,13,14,15,16,17,18,20}

cat<<EOF | crontab -
# min     hour      day     month     weekday command
${MIN}    ${HOUR}   *       *         *       /main.sh >> /log 2>&1
EOF

# see: https://github.com/dubiousjim/dcron/issues/13
# ignore using `exec` for `dcron` to get another pid instead of `1`
"$@"
# sleep infinity
