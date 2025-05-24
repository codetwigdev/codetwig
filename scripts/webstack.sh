#!/bin/bash
# webstack.sh - Full Web Stack Installer (Apache/NGINX, PHP, MariaDB, SSL, phpMyAdmin, UFW)
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
apt update && apt install -y software-properties-common curl gnupg2 unzip ufw

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
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
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

# Create web root and Coming Soon page
mkdir -p "$WEBROOT"
cat <<EOF > "$WEBROOT/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>$DOMAIN – Coming Soon</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      margin: 0;
      padding: 0;
      background: #161a21;
      color: #ffffff;
      font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      flex-direction: column;
      text-align: center;
    }
    h1 {
      font-size: 3rem;
      margin-bottom: 1rem;
    }
    p {
      font-size: 1.25rem;
      color: #aaaaaa;
    }
  </style>
</head>
<body>
  <h1>Coming Soon</h1>
  <p>We're setting things up. Check back shortly.</p>
</body>
</html>
EOF

# Optional phpinfo test page
cat <<EOF > "$WEBROOT/info.php"
<?php phpinfo();
EOF

chown -R www-data:www-data "$WEBROOT"

# Apache config
if [[ "$USE_APACHE" == "y" ]]; then
  a2dissite 000-default.conf >/dev/null 2>&1
  cat <<EOF > /etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    Redirect permanent / https://$DOMAIN/
</VirtualHost>
EOF
  a2ensite $DOMAIN.conf
  systemctl reload apache2

else
  cat <<EOF > /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://$DOMAIN\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

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

# Secure phpMyAdmin install
if [[ "$INSTALL_PHPMYADMIN" == "y" ]]; then
  echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive apt install -y phpmyadmin php-mbstring php-zip php-gd php-json php-curl
  if [[ "$USE_APACHE" == "y" ]]; then
    phpenmod mbstring
    systemctl restart apache2
  fi
  ln -s /usr/share/phpmyadmin "$WEBROOT/phpmyadmin"
  if [ -f /etc/phpmyadmin/config.inc.php ]; then
    sed -i "/AllowRoot/d" /etc/phpmyadmin/config.inc.php
    echo "\$cfg['Servers'][\$i]['AllowRoot'] = false;" >> /etc/phpmyadmin/config.inc.php
  fi
fi

# SSL setup
if [[ "$ENABLE_SSL" == "y" ]]; then
  apt install -y certbot
  if [[ "$USE_APACHE" == "y" ]]; then
    apt install -y python3-certbot-apache
    certbot --apache -d "$DOMAIN" -d "www.$DOMAIN" -n --agree-tos -m "$SSL_EMAIL"
  else
    apt install -y python3-certbot-nginx
    certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" -n --agree-tos -m "$SSL_EMAIL"
  fi
fi

# UFW firewall
if command -v ufw &> /dev/null; then
  ufw allow OpenSSH
  ufw allow 'Nginx Full' || ufw allow 'Apache Full'
  ufw --force enable
fi

# Done
echo -e "\n✅ Web stack installed for $DOMAIN"
if [[ "$CREATE_DB" == "y" ]]; then
  echo "🔐 DB credentials saved to /root/db_$DOMAIN.txt"
fi
echo "🌐 Visit: https://$DOMAIN"
echo "📄 PHP Info: https://$DOMAIN/info.php"
