#!/bin/sh
set -e
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
sed -i "s/bind-address.*/bind-address = 0.0.0.0/" \
/etc/mysql/mariadb.conf.d/50-server.cnf
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
MYSQL_ADMIN_PASSWORD=$(grep "WP_ADMIN_PASSWORD=" /run/secrets/credentials \
| cut -d'=' -f2)
if [ ! -d "/var/lib/mysql/mysql" ]; then
mariadb-install-db --user=mysql --datadir=/var/lib/mysql
mysqld --user=mysql &
until mysqladmin ping >/dev/null 2>&1; do
sleep 1
done
mysql <<EOF
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON wordpress.* TO '${MYSQL_USER}'@'%';
CREATE USER IF NOT EXISTS '${MYSQL_ADMIN_USER}'@'%'
IDENTIFIED BY '${MYSQL_ADMIN_PASSWORD}';
GRANT ALL PRIVILEGES ON wordpress.* TO '${MYSQL_ADMIN_USER}'@'%';
DELETE FROM mysql.user WHERE User=''; # supprime les comptes anonymes !
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF
mysqladmin shutdown -uroot -p"${MYSQL_ROOT_PASSWORD}"
fi
exec mysqld --user=mysql 