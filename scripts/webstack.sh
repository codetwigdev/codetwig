#!/bin/bash
# webstack.sh - Full Apache Stack Installer (PHP, MariaDB, SSL, phpMyAdmin)
# Author: CodeTwig
# Updated: 2025-05-24

set -e

echo "🌐 Web Stack Installer (Apache + SSL + MyBB DB)"

# Prompt for domain
read -p "Enter your domain (e.g. example.com): " DOMAIN
WEBROOT="/var/www/$DOMAIN"

# Prompt for SSL email
read -p "Enter email for SSL certificate registration (Let's Encrypt): " SSL_EMAIL

# Update system & install core packages
apt update && apt install -y software-properties-common curl gnupg2 unzip ufw apache2 libapache2-mod-php mariadb-server php php-cli php-mysql php-curl php-mbstring php-zip php-xml phpmyadmin

# Enable required services
systemctl enable apache2 mariadb
systemctl start apache2 mariadb

# Secure MariaDB and create MyBB database
DB_ROOT_PASS=$(openssl rand -base64 16)
DB_NAME="mybb_$(openssl rand -hex 4)"
DB_USER="user_$(openssl rand -hex 4)"
DB_PASS=$(openssl rand -base64 16)

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

echo -e "Database: $DB_NAME\nUser: $DB_USER\nPassword: $DB_PASS\nRoot Pass: $DB_ROOT_PASS" > /root/db_$DOMAIN.txt

# Setup website root with Coming Soon page
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
  <p>Your site is almost ready.</p>
</body>
</html>
EOF

# Optional phpinfo test page
cat <<EOF > "$WEBROOT/info.php"
<?php phpinfo();
EOF

# Link phpMyAdmin
ln -s /usr/share/phpmyadmin "$WEBROOT/phpmyadmin"

# Harden phpMyAdmin (disable root login)
if [ -f /etc/phpmyadmin/config.inc.php ]; then
  sed -i "/AllowRoot/d" /etc/phpmyadmin/config.inc.php
  echo "\$cfg['Servers'][\$i]['AllowRoot'] = false;" >> /etc/phpmyadmin/config.inc.php
fi

chown -R www-data:www-data "$WEBROOT"

# Apache config (redirect HTTP to HTTPS)
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

# SSL Setup with Certbot
apt install -y certbot python3-certbot-apache
certbot --apache -d "$DOMAIN" -d "www.$DOMAIN" -n --agree-tos -m "$SSL_EMAIL"

# UFW Firewall
if command -v ufw &> /dev/null; then
  ufw allow OpenSSH
  ufw allow 'Apache Full'
  ufw --force enable
fi

# Output summary
echo -e "\n✅ Apache stack installed for $DOMAIN"
echo "🔐 DB credentials saved to: /root/db_$DOMAIN.txt"
echo "🌐 Visit: https://$DOMAIN"
echo "📄 PHP Info: https://$DOMAIN/info.php"
echo "🛠 phpMyAdmin: https://$DOMAIN/phpmyadmin"
