#!/bin/bash
# phpmyadmin.sh - Install phpMyAdmin securely
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🧩 Installing phpMyAdmin..."

# Prompt for domain or IP
read -p "Enter your domain (or IP) to access phpMyAdmin (e.g. pma.example.com): " DOMAIN

# Update & install
apt update && apt install -y phpmyadmin php-mbstring php-zip php-gd php-json php-curl

# Symlink to NGINX root
ln -s /usr/share/phpmyadmin /var/www/$DOMAIN

# Set permissions
chown -R www-data:www-data /usr/share/phpmyadmin

# Create NGINX config
cat <<EOF > /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN;

    root /usr/share/phpmyadmin;
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

# Let's Encrypt SSL
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# Enable services
systemctl enable php7.4-fpm php8.1-fpm || true
systemctl enable nginx

echo "✅ phpMyAdmin is now accessible at https://$DOMAIN"
