FROM nginx:1.13
ARG TAG
LABEL TAG=${TAG}

ENV SSL_CERT=/certs/fullchain.crt
ENV SSL_CERT_KEY=/certs/fullchain.key
ENV FPM_STATIC_WEBROOT=/var/www/web/
ENV ENABLE_CONDITIONAL_BASIC_AUTH="NO"
ENV KEEPALIVE_TIMEOUT=200
ENV PROXY_STANDARD_FORWARD_PROTO="\$scheme"
ENV PROXY_STANDARD_FORWARD_PORT="\$server_port"
# envs for conditional basic auth settings
ENV CONDITIONAL_BASIC_AUTH_HEADER="http_x_forwarded_for"
ENV CONDITIONAL_BASIC_AUTH_REGEX="~172\..*"
ENV EXPOSE_PATH "/"

ADD src /

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y apache2-utils && \
    apt-get clean && \
    rm -Rf /usr/share/nginx/html/ && \
    # add www-data to root group (openshift requirement)
    adduser www-data root && \
    # for convenience
    ln -s /bin/bash /bin/ash && \
    touch /var/log/nginx/access.log && \
    touch /var/log/nginx/error.log && \
    # chmod conf dir so www-data can write to
    chown -R www-data:root /etc/nginx/ /usr/local/bin/run.sh /var/log/nginx/ /var/run/ /var/cache/nginx/ && \
    chmod -R go+rwx /etc/nginx/ /usr/local/bin/run.sh /var/log/nginx/ /var/run/ /var/cache/nginx/ && \
    chmod +x /usr/local/bin/run.sh

USER www-data

EXPOSE 9080 9443

CMD ["/usr/local/bin/run.sh", "nginx", "-g", "daemon off;"]
