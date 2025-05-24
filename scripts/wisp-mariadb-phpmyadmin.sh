#!/bin/bash
# WISP-Compatible MariaDB + phpMyAdmin Installer (Apache)
# Fully sets up remote-accessible MariaDB and phpMyAdmin for use with WISP panel

set -e

echo "🛠️ Setting up MariaDB + phpMyAdmin for WISP..."

read -p "Enter domain for phpMyAdmin (e.g. db.example.com): " DOMAIN
read -p "Enter email for SSL certificate registration (Let's Encrypt): " SSL_EMAIL
WEBROOT="/var/www/$DOMAIN"

# Update and install packages
apt update && apt install -y apache2 mariadb-server php php-cli php-mysql php-curl php-mbstring php-zip php-xml php-gd php-json unzip ufw certbot python3-certbot-apache

# Configure MariaDB to allow external connections
sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mariadb

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

# MariaDB secure install (or reuse password)
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
  echo "🔐 Saved MariaDB root password to /root/mariadb_root.txt"
fi

# Create 'wisp' user for each WISP IP
WISP_PASSWORD=$(openssl rand -base64 16)
WISP_IPS=(
  "45.45.236.53"
  "45.45.236.54"
  "45.45.236.55"
  "45.45.236.59"
  "23.164.88.53"
  "23.164.88.54"
  "23.164.88.55"
  "208.84.103.89"
)

for ip in "${WISP_IPS[@]}"; do
  mysql -uroot -p"$MYSQL_ROOT_PASS" -e "CREATE USER IF NOT EXISTS 'wisp'@'$ip' IDENTIFIED BY '$WISP_PASSWORD';"
  mysql -uroot -p"$MYSQL_ROOT_PASS" -e "GRANT ALL PRIVILEGES ON *.* TO 'wisp'@'$ip' WITH GRANT OPTION;"
done

echo -e "User: wisp\nPassword: $WISP_PASSWORD\nAllowed IPs: ${WISP_IPS[*]}" > /root/wisp_db_user.txt
echo "✅ Created 'wisp' user for all WISP panel IPs. Saved to /root/wisp_db_user.txt"

# Setup phpMyAdmin root site
mkdir -p "$WEBROOT"
ln -s /usr/share/phpmyadmin "$WEBROOT/phpmyadmin" 2>/dev/null || true

cat <<EOF > "$WEBROOT/index.html"
<!DOCTYPE html>
<html>
<head><title>WISP DB - $DOMAIN</title></head>
<body style="text-align:center;font-family:sans-serif;padding-top:20vh;">
  <h1>phpMyAdmin for WISP</h1>
  <p><a href="/phpmyadmin">Access phpMyAdmin</a></p>
</body>
</html>
EOF

chown -R www-data:www-data "$WEBROOT"

# Disable root login in phpMyAdmin
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

# Get SSL certificate
certbot --apache -d "$DOMAIN" -n --agree-tos -m "$SSL_EMAIL"

# Allow only WISP IPs to access MySQL port
ufw allow OpenSSH
for ip in "${WISP_IPS[@]}"; do
  ufw allow from $ip to any port 3306
done
ufw allow 'Apache Full'
ufw --force enable

# Output
echo -e "\n✅ phpMyAdmin ready at: https://$DOMAIN/phpmyadmin"
echo "🔐 WISP DB user saved at: /root/wisp_db_user.txt"