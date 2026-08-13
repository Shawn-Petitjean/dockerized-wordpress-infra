#!/bin/sh
set -e
apt-get update
apt-get install -y php-fpm php-mysql php-curl php-gd php-xml \
php-mbstring curl netcat-openbsd mariadb-client
# wp-cli n'est pas dans les dépôts Debian, téléchargement direct
curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x /usr/local/bin/wp