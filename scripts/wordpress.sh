#!/bin/bash
# wordpress.sh - Fully Automated WordPress Installer
# Author: CodeTwig
# Updated: 2025-05-23

set -e

# Prompt for domain
read -p "Enter your domain (e.g. example.com): " DOMAIN
read -p "Enter MySQL root password (will be set if blank): " MYSQL_ROOT_PW
DB_NAME="wordpress_$(date +%s)"
DB_USER="wpuser_$(date +%s)"
DB_PASS=$(openssl rand -base64 16)

# Update system
apt update && apt upgrade -y

# Install services
apt install -y nginx mariadb-server php php-fpm php-mysql curl unzip certbot python3-certbot-nginx

# Secure MariaDB (set root password if empty)
if [ -z "$MYSQL_ROOT_PW" ]; then
    MYSQL_ROOT_PW=$(openssl rand -base64 12)
    echo "Using generated MySQL root password: $MYSQL_ROOT_PW"
fi

echo "Securing MariaDB..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PW'; FLUSH PRIVILEGES;"

# Create WordPress database and user
echo "Creating DB and user..."
mysql -uroot -p"$MYSQL_ROOT_PW" <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Download WordPress
mkdir -p /var/www/$DOMAIN
cd /tmp
curl -O https://wordpress.org/latest.zip
unzip -q latest.zip
cp -r wordpress/* /var/www/$DOMAIN
chown -R www-data:www-data /var/www/$DOMAIN
rm -rf wordpress latest.zip

# Configure wp-config.php
cp /var/www/$DOMAIN/wp-config-sample.php /var/www/$DOMAIN/wp-config.php
sed -i "s/database_name_here/$DB_NAME/" /var/www/$DOMAIN/wp-config.php
sed -i "s/username_here/$DB_USER/" /var/www/$DOMAIN/wp-config.php
sed -i "s/password_here/$DB_PASS/" /var/www/$DOMAIN/wp-config.php

# Create NGINX config
cat <<EOF > /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/$DOMAIN;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
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

# SSL with Let's Encrypt
certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# Enable services
systemctl enable --now nginx mariadb php-fpm

# Save credentials
cat <<EOF > /root/wp_credentials_$DOMAIN.txt
Domain: $DOMAIN
MySQL Root Password: $MYSQL_ROOT_PW
Database: $DB_NAME
User: $DB_USER
User Password: $DB_PASS
EOF

echo "✅ WordPress installed at https://$DOMAIN"
echo "🔐 Credentials saved to /root/wp_credentials_$DOMAIN.txt"
