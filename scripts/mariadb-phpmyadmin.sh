#!/bin/bash
# Name: MariaDB + phpMyAdmin Installer
# Description: Installs and secures MariaDB, and sets up phpMyAdmin with optional DB and SSL.
# Tags: mariadb, mysql, phpmyadmin, ssl, database

set -e

echo "🛢️ Installing MariaDB + phpMyAdmin..."

read -p "Enter domain for phpMyAdmin (e.g. db.example.com): " DOMAIN
WEBROOT="/var/www/$DOMAIN"

read -p "Enable SSL with Let's Encrypt? (y/N): " ENABLE_SSL
ENABLE_SSL=$(echo "$ENABLE_SSL" | tr '[:upper:]' '[:lower:]')

read -p "Create a new database and user? (y/N): " CREATE_DB
CREATE_DB=$(echo "$CREATE_DB" | tr '[:upper:]' '[:lower:]')

apt update && apt install -y mariadb-server phpmyadmin php php-mysql php-mbstring php-zip php-gd php-json php-curl nginx certbot python3-certbot-nginx unzip

systemctl enable mariadb
systemctl start mariadb

# Secure MariaDB
MYSQL_ROOT_PASS=$(openssl rand -base64 12)
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "FLUSH PRIVILEGES;"

echo "🔐 MariaDB root password saved to /root/mariadb_root.txt"
echo "$MYSQL_ROOT_PASS" > /root/mariadb_root.txt

# Optional DB creation
if [[ "$CREATE_DB" == "y" ]]; then
  read -p "Database name: " DB_NAME
  read -p "Database user: " DB_USER
  DB_PASS=$(openssl rand -base64 12)

  mysql -uroot -p"$MYSQL_ROOT_PASS" <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

  echo "✅ DB credentials saved to /root/mariadb_user_$DB_NAME.txt"
  echo -e "Database: $DB_NAME\nUser: $DB_USER\nPassword: $DB_PASS" > /root/mariadb_user_$DB_NAME.txt
fi

# Setup web root and phpMyAdmin
mkdir -p "$WEBROOT"
ln -s /usr/share/phpmyadmin "$WEBROOT/phpmyadmin"
chown -R www-data:www-data "$WEBROOT"

# NGINX config
cat <<EOF > /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN;

    root $WEBROOT;
    index index.php index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# SSL
if [[ "$ENABLE_SSL" == "y" ]]; then
  certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN
fi

echo "✅ phpMyAdmin is ready at https://$DOMAIN/phpmyadmin"
