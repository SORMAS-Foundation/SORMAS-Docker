#!/bin/bash
# Copyright (c) 2006-2020, Salvatore Sanfilippo
# All rights reserved.
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
#    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#    * Neither the name of Redis nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# thanks to https://github.com/redis/redis/blob/unstable/utils/gen-test-certs.sh

# Generate some test certificates which are used by the regression test suite:
#
#   tls/ca.{crt,key}          Self signed CA certificate.
#   tls/client.{crt,key}      A certificate restricted for SSL client usage.
#   tls/server.{crt,key}      A certificate restricted for SSL server usage.
#   tls/dh/redis.dh              DH Params file.

generate_cert() {
  local name=$1
  local cn="$2"
  local opts="$3"

  mkdir tls/${name}
  local keyfile=tls/${name}/${name}.key
  local certfile=tls/${name}//${name}.crt

  [ -f $keyfile ] || openssl genrsa -out $keyfile 2048
  openssl req \
    -new -sha256 \
    -subj "/O=Redis Test/CN=$cn" \
    -key $keyfile |
    openssl x509 \
      -req -sha256 \
      -CA tls/ca/public/ca.crt \
      -CAkey tls/ca/private/ca.key \
      -CAserial tls/ca/ca.txt \
      -CAcreateserial \
      -days 365 \
      $opts \
      -out $certfile
}

mkdir -p tls/ca/private
mkdir tls/ca/public

[ -f tls/ca/private/ca.key ] || openssl genrsa -out tls/ca/private/ca.key 4096
openssl req \
  -x509 -new -nodes -sha256 \
  -key tls/ca/private/ca.key \
  -days 3650 \
  -subj '/O=Redis Test/CN=RedisCA' \
  -out tls/ca/public/ca.crt

cat >tls/openssl.cnf <<_END_
[ server_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = server

[ client_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = client
_END_

generate_cert server "redis" "-extfile tls/openssl.cnf -extensions server_cert"
generate_cert client "Client-only" "-extfile tls/openssl.cnf -extensions client_cert"
# generate_cert redis "Generic-cert"

mkdir -p tls/dh/
[ -f tls/dh/redis.dh ] || openssl dhparam -out tls/dh/redis.dh 2048

# import crt
CA_CRT=tls/ca/public/ca.crt
SERVER_CRT=tls/server/server.crt

echo "Importing ca certificate into truststore..."
ALIAS=$(openssl x509 -noout -subject -nameopt multiline -in "${CA_CRT}" | sed -n 's/ *commonName *= //p')
echo $ALIAS
TRUSTSTORE_FILE_NAME=redis.truststore.p12
TRUSTSTORE_FILE_PATH=tls/client/${TRUSTSTORE_FILE_NAME}
TRUSTSTORE_PASS=password

keytool -importcert -noprompt -keystore "${TRUSTSTORE_FILE_PATH}" -storetype pkcs12 -alias "${ALIAS}" -storepass "${TRUSTSTORE_PASS}" -file "${CA_CRT}" || exit 1

echo "Importing Redis Server certificate into truststore..."
ALIAS=$(openssl x509 -noout -subject -nameopt multiline -in "${SERVER_CRT}" | sed -n 's/ *commonName *= //p')
echo $ALIAS

keytool -importcert -noprompt -keystore "${TRUSTSTORE_FILE_PATH}" -storetype pkcs12 -alias "${ALIAS}" -storepass "${TRUSTSTORE_PASS}" -file "${CA_CRT}" || exit 1

echo "Importing client key into"
CLIENT_KEY=tls/client/client.key
CLIENT_CERT=tls/client/client.crt
P12_FILE=tls/client/redis.keystore.p12
PASSWORD=password
REDIS_KEY_NAME=redis_client

openssl pkcs12 -export -inkey "${CLIENT_KEY}" -out "${P12_FILE}" -password pass:"${PASSWORD}" -name "${REDIS_KEY_NAME}" -in "${CLIENT_CERT}" || exit 1
chmod +r ${P12_FILE}
