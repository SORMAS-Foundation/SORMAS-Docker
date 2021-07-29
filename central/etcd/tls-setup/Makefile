.PHONY: ca req clean

CFSSL	=  cfssl
JSON	=  cfssljson

all:  ca req


ca:
	mkdir -p certs/ca
	$(CFSSL) gencert -initca config/ca-csr.json | $(JSON) -bare certs/ca/ca

req:
	mkdir certs/etcd
	mkdir certs/peer-etcd
	$(CFSSL) gencert \
	  -ca certs/ca/ca.pem \
	  -ca-key certs/ca/ca-key.pem \
	  -config config/ca-config.json \
	  config/req-csr.json | $(JSON) -bare certs/etcd/etcd

	$(CFSSL) gencert \
	  -ca certs/ca/ca.pem \
	  -ca-key certs/ca/ca-key.pem \
	  -config config/ca-config.json \
	  config/req-csr.json | $(JSON) -bare certs/peer-etcd/peer-etcd


clean:
	rm -rf certs

