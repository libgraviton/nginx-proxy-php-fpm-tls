#!/bin/ash

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

export LD_PRELOAD=/usr/lib/runit-docker.so
exec runsvdir /etc/service
