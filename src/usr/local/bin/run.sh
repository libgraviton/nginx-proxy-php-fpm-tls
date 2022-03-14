#!/bin/ash

# mtail fifo?
if [ ! -z "${MTAIL_PATH}" ]
then
    # always create if doesn't exist
    if [ ! -p "${MTAIL_PATH}" ]
    then
        echo "--------- CREATING MTAIL FIFO AT ${MTAIL_PATH} ----------------"
        mkfifo "${MTAIL_PATH}"
    fi
fi

# start mtail instead?
if [[ "true" == "${MTAIL_START}" ]]; then
    exec /usr/bin/mtail -logtostderr -port 3093 -progs /etc/nginx/mtail/ -poll_interval 0 -logs "${MTAIL_PATH}"
    exit 0
fi

#### generate environment.json file
/usr/bin/php -d variables_order=E /opt/configurator/environment-json.php > /var/www/environment.json

echo "--------- GENERATED ENVIRONMENT.JSON ----------------"

cat -n /var/www/environment.json

echo "-----------------------------------------------------"

#### nginx config
/usr/bin/php -d variables_order=E /opt/configurator/configure.php /etc/nginx/nginx.conf

echo "--------- GENERATED CONFIG ----------------"

cat -n /etc/nginx/nginx.conf

echo "--------- STARTING NGINX ----------------"

exec "$@"
