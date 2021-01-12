<p align="center">
  <a href="https://sormas.org/">
    <img
      alt="SORMAS - Surveillance, Outbreak Response Management and Analysis System"
      src="../logo.png"
      height="200"
    />
  </a>
</p>

# Container Keycloak

The Keycloak container is built from `jboss/keycloak:11.0.0`.

It loads a predefined `SORMAS` Realm, `sormas` theme and a custom SPI `sormas-keycloak-service-provider`.

## SORMAS Realm

It comes predefined with 4 clients and 1 role.

Clients:
* `sormas-app` - client used by the mobile app to perform the OAuth2 Flow
* `sormas-rest` - client used by the backend to validate access trough the REST API
  * supports Basic and Bearer authentication
  * requires `REST_USER` role to pre-validate the access to the API
* `sormas-ui` - client used by the Sormas UI to authenticate the user trough OpenID
* `sormas-backend` - client used by the backend to handle user creation and password resets

Role: `REST_USER`

## Customization

The container comes with a custom SORMAS theme which provides custom styles for the following screens:
* Login
* Set Password
* Reset Password

Besides, custom styles there are some custom translation messages.

## Deploy

### Environment variables

The deployment can be customized through the following environment variables.
```
KEYCLOAK_DB_HOST
KEYCLOAK_DB_NAME
KEYCLOAK_DB_USER
KEYCLOAK_DB_PASSWORD
KEYCLOAK_DB_VENDOR

KEYCLOAK_ADMIN_USER
KEYCLOAK_ADMIN_PASSWORD

KEYCLOAK_CPUS
KEYCLOAK_MEM
KEYCLOAK_MEM_RESERVED

KEYCLOAK_SORMAS_UI_SECRET
KEYCLOAK_SORMAS_REST_SECRET
KEYCLOAK_SORMAS_BACKEND_SECRET

SORMAS_SERVER_URL
```

In case Keycloak is enabled as an Authentication provider, the following environment variables are needed for the SORMAS app:
```
CACERTS_PASS
KEYSTORE_PASS
```


### Manual configurations

Besides, the deployment variables, some manual configuration is required as well.

After deploy the following configurations have to be done from the Keycloak Admin Console:
1. Enable internationalization for `sormas-ui` and select the available locales and default locale.
2. Update email SMTP settings for the SORMAS realm

### Keycloak Configuration Upgrade

Keycloak configurations changes usually are part of the [SORMAS.json](https://github.com/hzi-braunschweig/SORMAS-Project/blob/development/sormas-base/setup/keycloak/SORMAS.json) file.

The SORMAS Keycloak image automatically adds any new realm resources by running the [update-realm.sh](update-realm.sh) script at startup.
This only imports new resources and doesn't remove/update existing resources.

Any update or deletion have to be done manually using the Keycloak Admin console.

