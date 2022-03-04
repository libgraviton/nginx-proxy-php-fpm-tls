# install our php stuff
FROM composer:2
COPY src/configurator /app
RUN cd /app && \
    composer install --ignore-platform-reqs --no-scripts && \
    composer dump-autoload --optimize --no-dev --classmap-authoritative

FROM nginx:1.21
ARG TAG
LABEL TAG=${TAG}

ENV TINI_VERSION=v0.19.0 \
    DEBIAN_FRONTEND=noninteractive

# global nginx settings
ENV RESOLVER=none \
    NO_RESOLVER=false \
    NO_SSL=false \
    RESOLVER_VALID=30s \
    RESOLVER_NO_IPV6=false \
    WORKER_PROCESSES=6 \
    WORKER_CONNECTIONS=1024 \
    CLIENT_BODY_BUFFER_SIZE=15M \
    CLIENT_MAX_BODY_SIZE=15M \
    KEEPALIVE_TIMEOUT=200 \
    SERVER_NAMES_HASH_BUCKET_SIZE=32 \
    SERVER_NAMES_HASH_MAX_SIZE=512 \
    SSL_CERT=/certs/fullchain.crt \
    SSL_CERT_KEY=/certs/fullchain.key \
    FPM_STATIC_WEBROOT=/var/www/web/ \
    FPM_STATUS_ALLOWED_NETWORK="172.0.0.0/8" \
    FPM_KEEPALIVE_CONN="true" \
    FPM_READ_TIMEOUT=240s \
    ENABLE_HTTP2="false" \
    GZIP_ENABLED="on" \
    GZIP_TYPES="text/css text/plain text/javascript application/javascript application/json application/x-javascript text/xml application/xml application/xml+rss application/xhtml+xml application/x-font-ttf application/x-font-opentype application/vnd.ms-fontobject image/svg+xml image/x-icon application/rss+xml application/atom_xml text/x-gettext-translation" \
    PROXY_STANDARD_FORWARD_PROTO="\$scheme" \
    PROXY_STANDARD_FORWARD_PORT="\$server_port" \
    CONDITIONAL_BASIC_AUTH_HEADER="http_x_forwarded_for" \
    CONDITIONAL_BASIC_AUTH_REGEX="~172\..*" \
    SYSLOG_SERVER="false" \
    SYSLOG_FACILITY="local7"

# server (vhost) specific settings
ENV SERVERNAME=localhost \
    ENABLE_CONDITIONAL_BASIC_AUTH="NO" \
    EXPOSE_PATH="/" \
    DEFAULT_SERVE="none" \
    ROOT_REDIRECT="false" \
    DEFAULT_VHOST="false"

# environment.json related
ENV ENVIRONMENT_JSON_PREFIX="ADMIN_"

###### END CONFIGURATION

ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini

RUN apt-get update && \
    apt-get upgrade -y && \
    TERM=xterm apt-get install -y --no-install-recommends busybox apache2-utils curl php-cli && \
    apt-get clean && \
    rm -Rf /usr/share/nginx/html/ && \
    # add www-data to root group (openshift requirement)
    adduser www-data root && \
    # for convenience
    ln -s /bin/bash /bin/ash && \
    touch /var/log/nginx/access.log && \
    touch /var/log/nginx/error.log && \
    mkdir /var/www

ADD src /
COPY --from=0 /app /opt/configurator

# chmod conf dir so www-data can write to
RUN chown -R www-data:root /var/www/ /etc/nginx/ /usr/local/bin/run.sh /var/log/nginx/ /var/run/ /var/cache/nginx/ /opt/configurator && \
    chmod -R go+rwx /var/www/ /etc/nginx/ /usr/local/bin/run.sh /var/log/nginx/ /var/run/ /var/cache/nginx/ && \
    chmod +x /usr/local/bin/run.sh && \
    chmod +x /tini

USER www-data

EXPOSE 9080 9443

ENTRYPOINT ["/tini", "--"]
CMD ["/usr/local/bin/run.sh", "nginx", "-g", "daemon off;"]
