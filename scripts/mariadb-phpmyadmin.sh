#!/bin/bash
# Name: MariaDB + phpMyAdmin Installer (Apache)
# Description: Secure MariaDB setup with phpMyAdmin and SSL (multi-run safe)
# Tags: mariadb, phpmyadmin, apache, ssl, database

set -e

echo "🛢️ Installing MariaDB + phpMyAdmin (Apache)..."

# Prompt for domain and SSL email
read -p "Enter domain for phpMyAdmin (e.g. db.example.com): " DOMAIN
read -p "Enter email for SSL certificate registration: " SSL_EMAIL
WEBROOT="/var/www/$DOMAIN"

# Update and install all required packages
apt update && apt install -y apache2 mariadb-server php php-cli php-mysql php-curl php-mbstring php-zip php-xml php-gd php-json unzip ufw certbot python3-certbot-apache

# phpMyAdmin (silent install if not already installed)
if ! dpkg -l | grep -qw phpmyadmin; then
  echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/admin-pass password" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/app-password-confirm password" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/app-pass password" | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive apt install -y phpmyadmin
fi

# Enable services
systemctl enable apache2 mariadb
systemctl start apache2 mariadb

# Use existing MariaDB root password if available, else generate and set it
if [ -f /root/mariadb_root.txt ]; then
  MYSQL_ROOT_PASS=$(cat /root/mariadb_root.txt)
else
  MYSQL_ROOT_PASS=$(openssl rand -base64 16)
  mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
  mysql -uroot -p"$MYSQL_ROOT_PASS" <<EOF
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF
  echo "$MYSQL_ROOT_PASS" > /root/mariadb_root.txt
  echo "🔐 MariaDB root password saved to /root/mariadb_root.txt"
fi

# Create secure DB and user
DB_NAME="db_$(openssl rand -hex 4)"
DB_USER="user_$(openssl rand -hex 4)"
DB_PASS=$(openssl rand -base64 16)

mysql -uroot -p"$MYSQL_ROOT_PASS" <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo -e "Database: $DB_NAME\nUser: $DB_USER\nPassword: $DB_PASS" > /root/mariadb_user_$DB_NAME.txt
echo "✅ DB credentials saved to /root/mariadb_user_$DB_NAME.txt"

# Setup web root and phpMyAdmin
mkdir -p "$WEBROOT"
ln -s /usr/share/phpmyadmin "$WEBROOT/phpmyadmin" 2>/dev/null || true

cat <<EOF > "$WEBROOT/index.html"
<!DOCTYPE html>
<html>
<head><title>phpMyAdmin – $DOMAIN</title></head>
<body style="text-align:center;font-family:sans-serif;padding-top:20vh;">
  <h1>phpMyAdmin for $DOMAIN</h1>
  <p><a href="/phpmyadmin">Launch phpMyAdmin</a></p>
</body>
</html>
EOF

chown -R www-data:www-data "$WEBROOT"

# Harden phpMyAdmin: disable root login
if [ -f /etc/phpmyadmin/config.inc.php ]; then
  sed -i "/AllowRoot/d" /etc/phpmyadmin/config.inc.php
  echo "\$cfg['Servers'][\$i]['AllowRoot'] = false;" >> /etc/phpmyadmin/config.inc.php
fi

# Apache vhost
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

a2ensite $DOMAIN.conf
systemctl reload apache2

# SSL via Let's Encrypt
certbot --apache -d "$DOMAIN" -n --agree-tos -m "$SSL_EMAIL"

# Firewall
if command -v ufw &> /dev/null; then
  ufw allow OpenSSH
  ufw allow 'Apache Full'
  ufw --force enable
fi

# Output
echo -e "\n✅ phpMyAdmin is ready at: https://$DOMAIN/phpmyadmin"
echo "📄 Root web: https://$DOMAIN"
