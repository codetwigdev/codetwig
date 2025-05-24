#!/bin/bash
# valet-linux.sh - Installs Laravel Valet on Linux (for dev use)
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🐘 Installing Laravel Valet (Linux)..."

# Update system
apt update && apt install -y php-cli php-curl php-mbstring php-xml php-mysql unzip curl git

# Install Composer globally
EXPECTED_CHECKSUM="$(curl -s https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '$EXPECTED_CHECKSUM') { echo '✔ Composer verified\n'; } else { echo '✖ Composer corrupt\n'; unlink('composer-setup.php'); exit(1); }"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

# Install Valet dependencies
composer global require cpriego/valet-linux

# Add Composer bin to path
export PATH="$HOME/.config/composer/vendor/bin:$PATH"

# Install Valet
valet install

echo "✅ Valet Linux installed."
echo "📁 You can now run 'valet park' in a dev folder and access sites at *.test"
