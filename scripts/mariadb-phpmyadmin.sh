#!/bin/bash
# mariadb-phpmyadmin.sh - Installs MariaDB and phpMyAdmin with HTTPS
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🛢️  Installing MariaDB + phpMyAdmin..."

# Prompt
read -p "Enter domain for phpMyAdmin (e.g. db.example.com): " DOMAIN

# Install MariaDB
apt update && apt install -y mariadb-server phpmyadmin php php-mysql php-mbstring php-zip php-gd php-json php-curl nginx certbot python3-certbot-nginx unzip

# Enable MariaDB
systemctl enable mariadb
systemctl start mariadb

# Secure MariaDB
echo "🔐 Securing MariaDB..."
MYSQL_ROOT_PASS=$(openssl rand -base64 12)

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "FLUSH PRIVILEGES;"

echo "✅ MariaDB secured. Root password saved to /root/mariadb_root.txt"
echo "$MYSQL_ROOT_PASS" > /root/mariadb_root.txt

# Optional: create DB and user
read -p "Create a new database and user now? (y/N): " CREATE_DB
if [[ "$CREATE_DB" =~ ^[Yy]$ ]]; then
  read -p "Database name: " DB_NAME
  read -p "Database user: " DB_USER
  DB_PASS=$(openssl rand -base64 12)

  mysql -uroot -p"$MYSQL_ROOT_PASS" <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

  echo "✅ DB: $DB_NAME / User: $DB_USER"
  echo "User password: $DB_PASS" > /root/mariadb_user_${DB_NAME}.txt
fi

# Set up phpMyAdmin
ln -s /usr/share/phpmyadmin /var/www/$DOMAIN
chown -R www-data:www-data /usr/share/phpmyadmin

# NGINX config
cat <<EOF > /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN;

    root /usr/share/phpmyadmin;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
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
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

echo "✅ phpMyAdmin available at https://$DOMAIN"
echo "🔐 MariaDB root password: $MYSQL_ROOT_PASS"
