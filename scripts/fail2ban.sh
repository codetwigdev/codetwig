#!/bin/bash
# fail2ban.sh - Install and configure Fail2Ban to block brute-force attacks
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🛡️  Installing Fail2Ban..."

# Install the package
apt update && apt install -y fail2ban

# Create basic jail.local config
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
destemail = root@localhost
sender = root@localhost
action = %(action_mwl)s

[sshd]
enabled = true

[nginx-http-auth]
enabled = true

[nginx-botsearch]
enabled = true

[nginx-wordpress]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 5
EOF

# Restart the service
systemctl restart fail2ban
systemctl enable fail2ban

# Show active jails
echo "✅ Fail2Ban installed and running. Active jails:"
fail2ban-client status

echo "ℹ️  Default ban time is 1 hour after 5 failed login attempts in 10 minutes."
