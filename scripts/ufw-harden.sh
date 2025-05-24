#!/bin/bash
# ufw-harden.sh - Configure UFW firewall with safe defaults
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🛡️  Setting up UFW firewall rules..."

# Install UFW if not present
apt update && apt install -y ufw

# Reset existing rules
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow OpenSSH

# Allow web traffic
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS

# Optional ports
read -p "Do you want to allow a custom port? (e.g. 3001 for Uptime Kuma) [y/N]: " ADD_PORT
if [[ "$ADD_PORT" =~ ^[Yy]$ ]]; then
  read -p "Enter port number to allow: " CUSTOM_PORT
  ufw allow $CUSTOM_PORT/tcp
fi

# Enable UFW
ufw --force enable

echo "✅ UFW firewall is now active."
ufw status verbose
