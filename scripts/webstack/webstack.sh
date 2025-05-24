#!/bin/bash
# webstack.sh - Apache Multi-Domain Installer (PHP, MariaDB, SSL, phpMyAdmin)
# Author: CodeTwig
# Updated: 2025-05-24

set -e

echo "🌐 Apache Multi-Domain Installer"

# Prompt for domain and SSL email
read -p "Enter your new domain (e.g. example.com): " DOMAIN
read -p "Enter email for SSL certificate registration (Let's Encrypt): " SSL_EMAIL
WEBROOT="/var/www/$DOMAIN"

# Detect and install global packages if needed
function install_if_missing() {
  for pkg in "$@"; do
    if ! dpkg -l | grep -qw "$pkg"; then
      echo "🔧 Installing missing package: $pkg"
      apt install -y "$pkg"
    fi
  done
}

# Update package list once
apt update

# Core stack
install_if_missing apache2 libapache2-mod-php php php-cli php-mysql php-curl php-mbstring php-zip php-xml mariadb-server

# phpMyAdmin (auto-config, only first time)
if ! dpkg -l | grep -qw phpmyadmin; then
  echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/admin-pass password" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/app-password-confirm password" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/app-pass password" | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive apt install -y phpmyadmin php-mbstring php-zip php-gd php-json php-curl
fi

# Enable services
systemctl enable apache2 mariadb
systemctl start apache2 mariadb

# Secure MyBB-style database for this domain
DB_ROOT_PASS=$(openssl rand -base64 16)
DB_NAME="mybb_$(openssl rand -hex 4)"
DB_USER="user_$(openssl rand -hex 4)"
DB_PASS=$(openssl rand -base64 16)

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASS';"
mysql -uroot -p"$DB_ROOT_PASS" <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo -e "Database: $DB_NAME\nUser: $DB_USER\nPassword: $DB_PASS\nRoot Pass: $DB_ROOT_PASS" > /root/db_$DOMAIN.txt

# Set up web root and pages
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
      font-family: sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      flex-direction: column;
      text-align: center;
    }
    h1 { font-size: 3rem; margin-bottom: 1rem; }
    p { font-size: 1.25rem; color: #aaa; }
  </style>
</head>
<body>
  <h1>Coming Soon</h1>
  <p>This site is almost ready.</p>
</body>
</html>
EOF

cat <<EOF > "$WEBROOT/info.php"
<?php phpinfo();
EOF

# Link phpMyAdmin to this domain (shared install)
ln -s /usr/share/phpmyadmin "$WEBROOT/phpmyadmin" 2>/dev/null || true

# Harden phpMyAdmin (once)
if [ -f /etc/phpmyadmin/config.inc.php ]; then
  sed -i "/AllowRoot/d" /etc/phpmyadmin/config.inc.php
  echo "\$cfg['Servers'][\$i]['AllowRoot'] = false;" >> /etc/phpmyadmin/config.inc.php
fi

chown -R www-data:www-data "$WEBROOT"

# Apache VirtualHost for new domain
if [ ! -f /etc/apache2/sites-available/$DOMAIN.conf ]; then
  a2dissite 000-default.conf >/dev/null 2>&1 || true
  cat <<EOF > /etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot $WEBROOT

    <Directory $WEBROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

  a2ensite $DOMAIN.conf
  systemctl reload apache2
fi

# Install Certbot + SSL (only once)
install_if_missing certbot python3-certbot-apache

# Request SSL and let Certbot handle HTTPS + redirect
certbot --apache -d "$DOMAIN" -d "www.$DOMAIN" -n --agree-tos -m "$SSL_EMAIL"

# Enable firewall (only once)
if command -v ufw &> /dev/null; then
  ufw allow OpenSSH
  ufw allow 'Apache Full'
  ufw --force enable
fi

# Output
echo -e "\n✅ Apache site added for $DOMAIN"
echo "🔐 DB credentials saved to: /root/db_$DOMAIN.txt"
echo "🌐 Visit: https://$DOMAIN"
echo "📄 PHP Info: https://$DOMAIN/info.php"
echo "🛠 phpMyAdmin: https://$DOMAIN/phpmyadmin"
