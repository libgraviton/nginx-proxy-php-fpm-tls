## nginx-proxy-php-fpm-tls

A versatile nginx image that can either serve as:

* Either normal proxy in front of an application
* As PHP-FPM frontend server

You can also configure

* Basic authentication
* TLS Client certificate authentication

### Modes

#### PHP-FPM mode

Set these to ENV variables to use it as PHP-FPM frontend server:

`FPM_PATH`: Path to the PHP entry file. Example:

```
- FPM_PATH=/var/www/web/app.php
```

`FPM_UPSTREAM`: Host of the PHP-FPM server (using port 9000). Example:

```
- FPM_UPSTREAM=upstream-php-container-name
```

#### Normal proxy mode

You can set the variable `PROXY_URL` to just proxy another server.

Example:

```
- PROXY_URL=http://other-container:9200
```

### Notes

This image does not use any LUA scripting - it generates the configuration on startup based on the environment variables.

### Ports and user

This image runs as non-root container. Thus, it cannot bind to port 80/443 inside the container.

Ports are:

* 9080 for http
* 9443 for https

Feel free to expose it as you need.

### SSL certificates

This image ships with a dummy certificate. Override the ENV variables or create volumes as the correct location
to use your real certificates.

### Basic authentication

The default username/password is user/thepassword.

You can override the user file located in `/etc/nginx/passwd` if you want to change that. You should change that.

## OpenShift compatibility

This image should be compatible with OpenShifts 'any but root' mode, as the user it runs is in the `root` group and
relevant directories have write access for 'others' if you run it with a random non existing UID/GID combination.

### Other ENV Variables

* `SSL_CERT=/certs/fullchain.crt`<br>
    Location of the SSL certificate (full chain). You can point this to a docker secret (recommended)
* `SSL_CERT_KEY=/certs/fullchain.key`<br>
    Location of the SSL certificate key. You can point this to a docker secret (recommended)
* `CLIENT_TLS_CERT`<br>
    Set this to a path of a CA file for client TLS authentication. Note that `OPTIONS` requests always be allowed without a cert.
* `FPM_STATIC_WEBROOT=/var/www/web/`<br>
    If you use it for PHP-FPM, you can set this to a directory inside the container to serve static assets
