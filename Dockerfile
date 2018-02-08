FROM debian:jessie-slim

RUN { \
        echo "deb http://deb.debian.org/debian wheezy main contrib non-free"; \
        echo "deb http://archive.debian.org/debian squeeze main contrib non-free"; \
    } | tee -a /etc/apt/sources.list.d/archive.list

ARG APACHE_VERSION=2.2.22-13+deb7u6
ARG APACHE_FCGID_VERSION=1:2.3.6-1.2+deb7u1
ARG PHP_VERSION=5.3.3-7+squeeze19

RUN apt-get update \
    && apt-get -y --force-yes --no-install-recommends install \
        apache2.2-common=${APACHE_VERSION} \
        apache2.2-bin=${APACHE_VERSION} \
        apache2-mpm-prefork=${APACHE_VERSION} \
        libapache2-mod-fcgid=${APACHE_FCGID_VERSION} \
        php5-cgi=${PHP_VERSION} \
        php5-common=${PHP_VERSION} \
    && rm -rf /var/lib/apt/lists/*

ENV APACHE_CONFDIR /etc/apache2

RUN { \
        echo "#!/bin/sh"; \
        echo; \
        echo "PHP_FCGI_MAX_REQUESTS=10000"; \
        echo; \
        echo "exec /usr/bin/php-cgi"; \
    } | tee /usr/local/bin/php-apache-wrapper \
    && chmod 755 /usr/local/bin/php-apache-wrapper

RUN { \
        echo "FcgidWrapper /usr/local/bin/php-apache-wrapper .php"; \
        echo "FcgidIPCDir /var/run/apache2/fcgid-sock"; \
        echo "FcgidProcessTableFile /var/run/apache2/fcgid-shm"; \
        echo "<FilesMatch ^.+\.php$>"; \
        echo "    Options +ExecCGI"; \
        echo "    SetHandler fcgid-script"; \
        echo "</FilesMatch>"; \
    } | tee -a ${APACHE_CONFDIR}/apache2.conf

# stdout and stderr logging
RUN set -ex \
    && . "${APACHE_CONFDIR}/envvars" \
    && ln -sfT /dev/stderr "${APACHE_LOG_DIR}/error.log" \
    && ln -sfT /dev/stdout "${APACHE_LOG_DIR}/access.log" \
    && ln -sfT /dev/stdout "${APACHE_LOG_DIR}/other_vhosts_access.log"

RUN a2enmod rewrite

#RUN echo "<?php phpinfo(); ?>" | tee /var/www/index.php

COPY ./vhosts/ ${APACHE_CONFDIR}/sites-enabled/

RUN usermod -u 1000 www-data && groupmod -g 1000 www-data

EXPOSE 80

CMD ["apache2ctl", "-DFOREGROUND"]
