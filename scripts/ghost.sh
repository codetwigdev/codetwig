#!/bin/bash
# ghost.sh - Fully Automated Ghost Blog Installer
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🚀 Installing Ghost Blog"

read -p "Enter your domain (e.g. blog.example.com): " DOMAIN

# Ensure required packages
apt update && apt install -y nginx mysql-server curl unzip nodejs npm sudo

# Setup Node.js LTS if not already
if ! command -v ghost &> /dev/null; then
  curl -sL https://deb.nodesource.com/setup_18.x | bash -
  apt install -y nodejs
fi

# Create user for Ghost
useradd -r -M -s /bin/false ghost

# Create site directory
mkdir -p /var/www/$DOMAIN
chown ghost:www-data /var/www/$DOMAIN
chmod 775 /var/www/$DOMAIN
cd /var/www/$DOMAIN

# Install Ghost CLI
npm install -g ghost-cli

# Install Ghost
ghost install \
  --url https://$DOMAIN \
  --db mysql \
  --dbhost localhost \
  --dir /var/www/$DOMAIN \
  --process systemd \
  --start \
  --no-prompt \
  --no-setup-nginx \
  --no-setup-systemd \
  --no-setup-ssl

# Setup systemd manually (needed for full auto)
ghost setup systemd

# Configure NGINX manually
cat <<EOF > /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:2368;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Setup SSL
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# Final ghost SSL + nginx step
ghost setup nginx ssl

echo "✅ Ghost installed at https://$DOMAIN"
