#!/bin/bash
# Name: MyBB Forum Installer
# Description: Fully automated MyBB install with Apache, PHP, and MariaDB. Outputs credentials to a text file.
# Tags: mybb, forum, php, mysql, apache

set -e

echo "🧩 Installing MyBB Forum Stack..."

# Prompt for domain
read -p "Enter your domain (e.g. forum.example.com): " DOMAIN
WEBROOT="/var/www/$DOMAIN"
DB_NAME="mybb_$(openssl rand -hex 3)"
DB_USER="mybbuser_$(openssl rand -hex 2)"
DB_PASS="$(openssl rand -base64 12)"
ROOT_PASS="$(openssl rand -base64 14)"

# Update and install LAMP stack
apt update && apt install -y apache2 mariadb-server php libapache2-mod-php php-mysql php-gd php-curl php-mbstring unzip wget

# Secure MariaDB
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASS'; FLUSH PRIVILEGES;"

# Create MyBB database
mysql -uroot -p"$ROOT_PASS" -e "CREATE DATABASE $DB_NAME;"
mysql -uroot -p"$ROOT_PASS" -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -uroot -p"$ROOT_PASS" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"

# Download and extract MyBB
mkdir -p "$WEBROOT"
cd "$WEBROOT"
wget https://resources.mybb.com/downloads/mybb_1827.zip -O mybb.zip
unzip mybb.zip && rm mybb.zip
cp -r Upload/* .
rm -rf Upload Documentation

# Set permissions
chown -R www-data:www-data "$WEBROOT"
chmod -R 755 "$WEBROOT"

# Apache config
cat <<EOF > /etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost *:80>
    ServerAdmin webmaster@$DOMAIN
    ServerName $DOMAIN
    DocumentRoot $WEBROOT

    <Directory $WEBROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOF

a2ensite $DOMAIN.conf
a2enmod rewrite
systemctl reload apache2

# Save credentials
mkdir -p /root/mybb-install
CRED_FILE="/root/mybb-install/$DOMAIN.txt"
echo "MyBB installation complete!" > "$CRED_FILE"
echo "Domain: http://$DOMAIN" >> "$CRED_FILE"
echo "MyBB Admin Path: http://$DOMAIN/admin" >> "$CRED_FILE"
echo "Database: $DB_NAME" >> "$CRED_FILE"
echo "DB User: $DB_USER" >> "$CRED_FILE"
echo "DB Pass: $DB_PASS" >> "$CRED_FILE"
echo "MariaDB root pass: $ROOT_PASS" >> "$CRED_FILE"

echo "✅ Installation complete. Visit http://$DOMAIN to finish setup."
echo "🔐 Credentials saved to $CRED_FILE"
