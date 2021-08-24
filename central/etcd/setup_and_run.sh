#!/bin/bash

# fork to background
/usr/local/bin/etcd --config-file /etc/etcd/etcd.yml &

echo "starting import"
sleep 3

if [ ! -f /srv/fixtures/server-descriptors.json ]; then
    echo "/srv/fixtures/server-descriptors.json not found!"
    exit 1
fi


for row in $(jq -c '.[]' < /srv/fixtures/server-descriptors.json); do
   key=$(echo "${row}" | jq -r .key)
   value=$(echo "${row}" | jq -r .value)
   echo "Inserting ${key} : ${value}"
   etcdctl --cacert=/srv/certs/ca.pem --endpoints=https://localhost:2379 put "$key" "$value" || exit 1
done

echo "import done"

echo "setup root"
etcdctl role add root
etcdctl user add root --new-user-password="${ROOT_PWD}"
etcdctl user grant-role root root

echo "setting up s2s"
etcdctl role add s2s-client-role
etcdctl user add s2s-client --new-user-password="${S2S_CLIENT_PWD}"
etcdctl role grant-permission s2s-client-role --prefix=true read /s2s/
etcdctl user grant-role s2s-client s2s-client-role

etcdctl auth enable

echo  "terminating"
ps aux  |  grep -i etcd  |  awk '{print $2}'  |  xargs kill -15

sleep 3

/usr/local/bin/etcd --config-file /etc/etcd/etcd.yml
