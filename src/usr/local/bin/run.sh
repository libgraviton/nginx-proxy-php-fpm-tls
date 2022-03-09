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

# start mtail?
if [[ "true" == "${MTAIL_START}" ]]; then
    exec /usr/bin/mtail -logtostderr -port 3093 -progs /etc/nginx/mtail/ -poll_interval 0 -logs "${MTAIL_PATH}"
    exit 0
fi

/usr/bin/php -d variables_order=E /opt/configurator/configure.php /etc/nginx/nginx.conf

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

echo "--------- GENERATED CONFIG ----------------"

cat -n /etc/nginx/nginx.conf

echo "--------- STARTING NGINX ----------------"

exec "$@"
