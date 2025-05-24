#!/bin/bash
# nodejs.sh - Install latest LTS version of Node.js + npm
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🟢 Installing latest Node.js LTS..."

# Install prerequisites
apt update && apt install -y curl sudo

# Install n (Node.js version manager)
curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o /usr/local/bin/n
chmod +x /usr/local/bin/n

# Install latest LTS
n lts

# Ensure npm is up-to-date
npm install -g npm

# Save version info
NODE_VER=$(node -v)
NPM_VER=$(npm -v)

echo "✅ Node.js $NODE_VER and npm $NPM_VER installed"
