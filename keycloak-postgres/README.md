<p align="center">
  <a href="https://sormas.org/">
    <img
      alt="SORMAS - Surveillance, Outbreak Response Management and Analysis System"
      src="../logo.png"
      height="200"
    />
  </a>
</p>

# Container Postgres

The postgres container is build from image `postgres:10-alpine`.  It uses a prepared `/etc/postgresql/postgresql.conf` file with parameter:

```shell
max_prepared_transactions = 110         # zero disables the feature
```

This is needed to successfully deploy Keycloak for SORMAS.

<p align="center">
  <a href="https://sormas.org/">
    <img
      src="https://www.grouplink.de/wp-content/uploads/2014/01/logo_netzlink-300x300.jpg"
      title="netzlink-Logo_weißrot"
      alt="netzlink-Logo_weißrot"
      height="200"
    />
  </a>
</p>

