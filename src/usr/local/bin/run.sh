#!/bin/ash

PROXYMODE=none

## basics
# resolver
sed -i 's@THERESOLVER@'"$RESOLVER"'@' /etc/nginx/conf.d/default.conf
sed -i 's@THESERVERNAME@'"$SERVERNAME"'@' /etc/nginx/conf.d/default.conf
sed -i 's@RESOLVERVALID@'"$RESOLVER_VALID"'@' /etc/nginx/conf.d/default.conf

# php-fpm proxy mode
if [ ! -z ${FPM_UPSTREAM+x} ] && [ ! -z ${FPM_PATH+x} ]; then

    # upstream host name --> global var!
    sed -i 's@UPSTREAMNAME@'"$FPM_UPSTREAM"'@' /etc/nginx/conf.d/dynamic/global/aa-upstreamname.conf

    sed -i 's@EXPOSEPATH@'"$EXPOSE_PATH"'@' /etc/nginx/templates/proxies/upstream-fpm-server.conf

    # replace FPM path (filename of upstream)
    sed -i 's@FPMUPSTREAMPATH@'"$FPM_PATH"'@' /etc/nginx/templates/proxies/upstream-fpm-server.conf

    # replace local static webroot
    sed -i 's@FPMSTATICWEBROOT@'"$FPM_STATIC_WEBROOT"'@' /etc/nginx/templates/proxies/upstream-fpm-server.conf

    # the server block relevant part to its final destination
    cp /etc/nginx/templates/proxies/upstream-fpm-server.conf /etc/nginx/conf.d/dynamic/proxy.conf

    PROXYMODE=fpm
fi

# normal forward proxy mode
if [ ! -z ${PROXY_URL+x} ]; then
    # replace FPM path (filename of upstream)
    sed -i 's@EXPOSEPATH@'"$EXPOSE_PATH"'@' /etc/nginx/templates/proxies/upstream-standard-server.conf
    sed -i 's@UPSTREAMNAME@'"$PROXY_URL"'@' /etc/nginx/conf.d/dynamic/global/aa-upstreamname.conf
    sed -i 's@FORWARDPROTO@'"$PROXY_STANDARD_FORWARD_PROTO"'@' /etc/nginx/templates/proxies/upstream-standard-server.conf
    sed -i 's@FORWARDPORT@'"$PROXY_STANDARD_FORWARD_PORT"'@' /etc/nginx/templates/proxies/upstream-standard-server.conf

    # the server block relevant part to its final destination
    cp /etc/nginx/templates/proxies/upstream-standard-server.conf /etc/nginx/conf.d/dynamic/proxy.conf

    PROXYMODE=standard
fi

# no proxymode? then make static hosting to /var/www
if [ "${PROXYMODE}" = "none" ]; then
    cp /etc/nginx/templates/proxies/static-root.conf /etc/nginx/conf.d/dynamic/proxy.conf

    # default serve file?
    if [ ! "${DEFAULT_SERVE}" = "none" ]; then
        sed -i 's@DEFAULTSERVE@'"$DEFAULT_SERVE"'@g' /etc/nginx/templates/location/default_serve.conf
        cp /etc/nginx/templates/location/default_serve.conf /etc/nginx/conf.d/dynamic/location/
    fi
fi

# tls client cert
if [ ! -z ${CLIENT_TLS_CERT+x} ]; then
    # client tls cert
    sed -i 's@CLIENTTLSCERT@'"$CLIENT_TLS_CERT"'@g' /etc/nginx/templates/server/tls-cert-auth.conf

    # the server block relevant part to its final destination
    cp /etc/nginx/templates/server/tls-cert-auth.conf /etc/nginx/conf.d/dynamic/server/zz-tls-cert-auth.conf
fi

# basic auth stuff
if [ ! -z ${BASIC_USERNAME+x} ] && [ ! -z ${BASIC_PASSWORD+x} ]; then
    htpasswd -D /etc/nginx/passwd user
    htpasswd -b /etc/nginx/passwd ${BASIC_USERNAME} ${BASIC_PASSWORD}

    # conditional basic auth
    if [[ $ENABLE_CONDITIONAL_BASIC_AUTH = "YES" ]]; then
        sed -i 's@CONDITIONALBASICAUTHHEADER@'"$CONDITIONAL_BASIC_AUTH_HEADER"'@' /etc/nginx/templates/global/basic_auth_conditional.conf
        sed -i 's@CONDITIONALBASICAUTHREGEX@'"$CONDITIONAL_BASIC_AUTH_REGEX"'@' /etc/nginx/templates/global/basic_auth_conditional.conf
        cp /etc/nginx/templates/global/basic_auth_conditional.conf /etc/nginx/conf.d/dynamic/global/
    else
        cp /etc/nginx/templates/global/basic_auth_on.conf /etc/nginx/conf.d/dynamic/global/
    fi

    cp /etc/nginx/templates/location/basic_auth_rules.conf /etc/nginx/conf.d/dynamic/location/
fi

# ssl cert paths
sed -i 's@SSLCERTPATH@'"$SSL_CERT"'@' /etc/nginx/conf.d/dynamic/server/ssl_certs.conf
sed -i 's@SSLCERTKEYPATH@'"$SSL_CERT_KEY"'@' /etc/nginx/conf.d/dynamic/server/ssl_certs.conf

# timeout
sed -i 's@KEEPALIVETIMEOUT@'"$KEEPALIVE_TIMEOUT"'@' /etc/nginx/nginx.conf

# basic stuff
sed -i 's@GZIPENABLED@'"$GZIP_ENABLED"'@' /etc/nginx/conf.d/default.conf
sed -i 's@GZIPTYPES@'"$GZIP_TYPES"'@' /etc/nginx/conf.d/default.conf

# location rules
COUNTER=1

for var in ${!RULES_*}; do
    IFS='#' read -ra ADDR <<< "${!var}"

    if [ ! -z "${ADDR[0]}" ] && [ ! -z "${ADDR[0]}" ]; then
        sed 's@THELOCATION@'"${ADDR[0]}"'@' /etc/nginx/templates/server/location-rule.conf > /tmp/config
        sed -i 's@THEMETHODS@'"${ADDR[1]}"'@' /tmp/config

        mv /tmp/config /etc/nginx/conf.d/dynamic/server/rule-${COUNTER}.conf

        COUNTER=$[COUNTER+1]
    fi
done

#### generate environment.json file

fileName="/var/www/environment.json"
tmpFile="/tmp/environment_variables.log"
variables=()

# Making a grep on environment variable starting with BAP_ and save it tmp
env | grep -o "^${ENVIRONMENT_JSON_PREFIX}.*=.*" > $tmpFile

# LOOP the items, but last without coma for correct json
while read VARIABLE
do
    myvar=${VARIABLE#*=}
    variables+=("\"${myvar%;*}\":\"${myvar#*;}\"")
done < $tmpFile

# Config output join by coma
environmentString=$(IFS=, ; echo "${variables[*]}")

# Save to file
echo "{$environmentString}" > $fileName

rm -f $tmpFile

exec "$@"
