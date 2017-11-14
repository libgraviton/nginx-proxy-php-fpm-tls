#!/bin/ash

if [ ! -z ${BASIC_USERNAME+x} ] && [ ! -z ${BASIC_PASSWORD+x} ]; then
    htpasswd -D /etc/nginx/passwd user
    htpasswd -b /etc/nginx/passwd ${BASIC_USERNAME} ${BASIC_PASSWORD}
fi

# php-fpm proxy mode
if [ ! -z ${FPM_UPSTREAM+x} ] && [ ! -z ${FPM_PATH+x} ]; then
    # replace the configured fpm upstream by env
    sed -i 's@FPMUPSTREAMHOSTNAME@'"$FPM_UPSTREAM"'@' /etc/nginx/templates/upstream-fpm-upstream.conf

    # replace FPM path (filename of upstream)
    sed -i 's@FPMUPSTREAMPATH@'"$FPM_PATH"'@' /etc/nginx/templates/upstream-fpm-server.conf

    # replace local static webroot
    sed -i 's@FPMSTATICWEBROOT@'"$FPM_STATIC_WEBROOT"'@' /etc/nginx/templates/upstream-fpm-server.conf

    # copy the php upstream block to its final destination
    cp /etc/nginx/templates/upstream-fpm-upstream.conf /etc/nginx/conf.d/dynamic/upstreams/upstream.conf

    # the server block relevant part to its final destination
    cp /etc/nginx/templates/upstream-fpm-server.conf /etc/nginx/conf.d/dynamic/proxy.conf
fi

# normal forward proxy mode
if [ ! -z ${PROXY_URL+x} ]; then
    # replace FPM path (filename of upstream)
    sed -i 's@PROXYURL@'"$PROXY_URL"'@' /etc/nginx/templates/upstream-standard-server.conf

    # the server block relevant part to its final destination
    cp /etc/nginx/templates/upstream-standard-server.conf /etc/nginx/conf.d/dynamic/proxy.conf
fi

# tls client cert
if [ ! -z ${CLIENT_TLS_CERT+x} ]; then
    # client tls cert
    sed -i 's@CLIENTTLSCERT@'"$CLIENT_TLS_CERT"'@g' /etc/nginx/templates/tls-cert-auth.conf

    # the server block relevant part to its final destination
    cp /etc/nginx/templates/tls-cert-auth.conf /etc/nginx/conf.d/dynamic/variables/zz-tls-cert-auth.conf
fi

# conditional basic auth
sed -i 's@CONDITIONALBASICAUTH@'"$ENABLE_CONDITIONAL_BASIC_AUTH"'@' /etc/nginx/conf.d/dynamic/variables/conditional_basic_auth.conf

# ssl cert paths
sed -i 's@SSLCERTPATH@'"$SSL_CERT"'@' /etc/nginx/conf.d/dynamic/variables/ssl_certs.conf
sed -i 's@SSLCERTKEYPATH@'"$SSL_CERT_KEY"'@' /etc/nginx/conf.d/dynamic/variables/ssl_certs.conf

# timeout
sed -i 's@KEEPALIVETIMEOUT@'"$KEEPALIVE_TIMEOUT"'@' /etc/nginx/nginx.conf

exec "$@"
