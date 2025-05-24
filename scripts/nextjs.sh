#!/bin/bash
# nextjs.sh - Deploy a Next.js app using PM2 and NGINX
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "⚙️  Setting up Next.js production deployment..."

# Prompt for info
read -p "Enter your domain (e.g. next.example.com): " DOMAIN
read -p "Enter Git repo URL (HTTPS): " REPO
read -p "Enter project folder name (default: nextapp): " FOLDER
FOLDER=${FOLDER:-nextapp}

# Install dependencies
apt update && apt install -y git nginx curl
npm install -g pm2

# Clone project
cd /var/www
git clone $REPO $FOLDER
cd $FOLDER

# Install and build Next.js app
npm install
npm run build

# Start with PM2
pm2 start npm --name "$FOLDER" -- start
pm2 save
pm2 startup systemd -u $USER --hp $HOME

# Configure NGINX
cat <<EOF > /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# SSL setup
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

echo "✅ Next.js app deployed at https://$DOMAIN"
