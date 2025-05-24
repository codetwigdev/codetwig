#!/bin/bash
# webstack.sh - Full Web Stack Installer (NGINX, PHP, MariaDB, phpMyAdmin, SSL)
# Author: CodeTwig
# Updated: 2025-05-24

set -e

echo "🌐 Web Stack Installer"

# Prompt for domain
read -p "Enter your domain (e.g. example.com): " DOMAIN
WEBROOT="/var/www/$DOMAIN"

# Prompt for SSL
read -p "Enable Let's Encrypt SSL? (y/N): " ENABLE_SSL
ENABLE_SSL=$(echo "$ENABLE_SSL" | tr '[:upper:]' '[:lower:]')

# Prompt for SSL email if enabled
if [[ "$ENABLE_SSL" == "y" ]]; then
  read -p "Enter email for SSL certificate registration (Let's Encrypt): " SSL_EMAIL
fi

# Prompt for Apache instead of NGINX
read -p "Use Apache instead of NGINX? (y/N): " USE_APACHE
USE_APACHE=$(echo "$USE_APACHE" | tr '[:upper:]' '[:lower:]')

# Prompt for DB
read -p "Create a MariaDB database and user? (y/N): " CREATE_DB
CREATE_DB=$(echo "$CREATE_DB" | tr '[:upper:]' '[:lower:]')

# Prompt for phpMyAdmin
read -p "Install phpMyAdmin? (y/N): " INSTALL_PHPMYADMIN
INSTALL_PHPMYADMIN=$(echo "$INSTALL_PHPMYADMIN" | tr '[:upper:]' '[:lower:]')

# Update & install base packages
apt update && apt install -y software-properties-common curl gnupg2 unzip

# Install web server
if [[ "$USE_APACHE" == "y" ]]; then
  apt install -y apache2 libapache2-mod-php
  systemctl enable apache2
  systemctl start apache2
else
  apt install -y nginx
  systemctl enable nginx
  systemctl start nginx
fi

# Install PHP and modules
apt install -y php php-fpm php-mysql php-cli php-curl php-mbstring php-zip php-xml

# Install MariaDB and secure
apt install -y mariadb-server
systemctl enable mariadb
systemctl start mariadb

DB_INFO=""

if [[ "$CREATE_DB" == "y" ]]; then
  DB_ROOT_PASS=$(openssl rand -base64 12)
  DB_NAME="site_$(date +%s)"
  DB_USER="user_$(date +%s)"
  DB_PASS=$(openssl rand -base64 12)

  mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASS';"
  mysql -uroot -p"$DB_ROOT_PASS" <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

  DB_INFO="Database: $DB_NAME
User: $DB_USER
Password: $DB_PASS
Root Pass: $DB_ROOT_PASS"
  echo -e "$DB_INFO" > /root/db_$DOMAIN.txt
fi

# Set up web root and Coming Soon page
mkdir -p "$WEBROOT"
curl -sL https://codetwig.dev/assets/coming-soon.zip -o /tmp/coming-soon.zip
unzip -o /tmp/coming-soon.zip -d "$WEBROOT"
rm /tmp/coming-soon.zip
chown -R www-data:www-data "$WEBROOT"

# Configure web server
if [[ "$USE_APACHE" == "y" ]]; then
  cat <<EOF > /etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $WEBROOT
    <Directory $WEBROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
  a2ensite $DOMAIN
  systemctl reload apache2
else
  cat <<EOF > /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root $WEBROOT;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ =404;
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
fi

# Install phpMyAdmin
if [[ "$INSTALL_PHPMYADMIN" == "y" ]]; then
  apt install -y phpmyadmin
  ln -s /usr/share/phpmyadmin "$WEBROOT/phpmyadmin"
fi

# SSL
if [[ "$ENABLE_SSL" == "y" ]]; then
  apt install -y certbot
  if [[ "$USE_APACHE" == "y" ]]; then
    apt install -y python3-certbot-apache
    certbot --apache -d "$DOMAIN" -n --agree-tos -m "$SSL_EMAIL"
  else
    apt install -y python3-certbot-nginx
    certbot --nginx -d "$DOMAIN" -n --agree-tos -m "$SSL_EMAIL"
  fi
fi

# Done
echo -e "\n✅ Web stack installed for $DOMAIN"
if [[ "$CREATE_DB" == "y" ]]; then
  echo "🔐 DB credentials saved to /root/db_$DOMAIN.txt"
fi
