#!/bin/bash
# nginx-ssl.sh - Install NGINX and set up Let's Encrypt SSL
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🌐 Setting up NGINX with HTTPS..."

# Prompt for domain and root folder
read -p "Enter your domain (e.g. example.com): " DOMAIN
read -p "Enter web root path (default: /var/www/$DOMAIN): " ROOT
ROOT=${ROOT:-/var/www/$DOMAIN}

# Install NGINX and Certbot
apt update && apt install -y nginx certbot python3-certbot-nginx

# Create web root
mkdir -p $ROOT
echo "<h1>$DOMAIN is working!</h1>" > $ROOT/index.html

# Set permissions
chown -R www-data:www-data $ROOT

# Create NGINX config
cat <<EOF > /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root $ROOT;

    index index.html index.htm index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Get SSL cert
certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

echo "✅ HTTPS site live at https://$DOMAIN"
