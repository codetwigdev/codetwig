#!/bin/bash
# webstack-nginx.sh - Install NGINX, PHP, MariaDB, and optional SSL
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🧱 Web Stack Installer (NGINX + PHP + MariaDB + SSL)"

read -p "Enter your domain (e.g. example.com): " DOMAIN
read -p "Enter site root path (default: /var/www/$DOMAIN): " ROOT
ROOT=${ROOT:-/var/www/$DOMAIN}
read -p "Install MariaDB and create DB/user? (y/N): " INSTALL_DB
read -p "Enable Let's Encrypt SSL? (y/N): " ENABLE_SSL

# Update and install packages
apt update && apt install -y nginx php php-fpm php-mysql php-cli php-curl php-mbstring php-zip php-xml mariadb-server unzip curl certbot python3-certbot-nginx

# Set up web root
mkdir -p "$ROOT"
echo "<?php phpinfo(); ?>" > "$ROOT/index.php"
chown -R www-data:www-data "$ROOT"

# Create NGINX config
cat <<EOF > /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root $ROOT;

    index index.php index.html index.htm;

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

# MariaDB setup
if [[ "$INSTALL_DB" =~ ^[Yy]$ ]]; then
  echo "📦 Setting up MariaDB..."
  MYSQL_ROOT_PASS=$(openssl rand -base64 12)
  DB_NAME="webdb_$(date +%s)"
  DB_USER="user_$(date +%s)"
  DB_PASS=$(openssl rand -base64 12)

  systemctl enable mariadb
  systemctl start mariadb

  mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
  mysql -uroot -p"$MYSQL_ROOT_PASS" <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

  echo "✅ DB: $DB_NAME / User: $DB_USER"
  echo "🔐 Saved to /root/mysql_credentials_$DOMAIN.txt"
  echo -e "DB: $DB_NAME\nUser: $DB_USER\nPassword: $DB_PASS\nRoot Pass: $MYSQL_ROOT_PASS" > /root/mysql_credentials_$DOMAIN.txt
fi

# SSL setup
if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
  echo "🔒 Enabling SSL for $DOMAIN"
  certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN
fi

echo "✅ Web stack is ready at http${ENABLE_SSL:+s}://$DOMAIN"
