#!/bin/sh
set -e
# Lecture des variables
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_USER="${MYSQL_USER}"
MYSQL_DATABASE="${MYSQL_DATABASE}"
DOMAIN_NAME="${DOMAIN_NAME}"
WP_ADMIN_USER=$(grep "WP_ADMIN_USER=" /run/secrets/credentials | cut -d'=' -f2)
WP_ADMIN_PASSWORD=$(grep "WP_ADMIN_PASSWORD=" /run/secrets/credentials | cut -d'=' -f2)
WP_USER=$(grep "WP_USER=" /run/secrets/credentials | cut -d'=' -f2)
WP_USER_PASSWORD=$(grep "WP_USER_PASSWORD=" /run/secrets/credentials | cut -d'=' -f2)
if [ ! -f "/var/www/wordpress/wp-config-sample.php" ]; then
mkdir -p /var/www/wordpress
cp -r /usr/src/wordpress/. /var/www/wordpress/
# Attendre que MariaDB soit VRAIMENT prête (pas juste que le port réponde)
until mysqladmin ping -h mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
--silent >/dev/null 2>&1; do
echo "En attente de MariaDB..."
sleep 2
done
# Création de wp-config.php
wp config create \
--path=/var/www/wordpress \
--dbname="${MYSQL_DATABASE}" \
--dbuser="${MYSQL_USER}" \
--dbpass="${MYSQL_PASSWORD}" \
--dbhost="mariadb" \
--allow-root
# Installation WordPress
wp core install \
--path=/var/www/wordpress \
--url="${DOMAIN_NAME}" \
--title="Inception" \
--admin_user="${WP_ADMIN_USER}" \
--admin_password="${WP_ADMIN_PASSWORD}" \
--admin_email="admin@${DOMAIN_NAME}" \
--allow-root
# Second utilisateur (requis par le sujet)
wp user create "${WP_USER}" "user@${DOMAIN_NAME}" \
--user_pass="${WP_USER_PASSWORD}" \
--role=author \
--path=/var/www/wordpress \
--allow-root
fi
mkdir -p /run/php
exec php-fpm7.4 -F # PID 1, foreground
