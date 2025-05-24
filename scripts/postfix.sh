#!/bin/bash
# postfix.sh - Send-only Postfix SMTP installer
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "📬 Installing Postfix (send-only mail server)..."

# Prompt for FQDN
read -p "Enter your server's FQDN (e.g. mail.example.com): " FQDN

# Set hostname
hostnamectl set-hostname "$FQDN"

# Install Postfix (non-interactive)
debconf-set-selections <<< "postfix postfix/mailname string $FQDN"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt update && apt install -y postfix mailutils

# Configure main.cf
postconf -e "myhostname = $FQDN"
postconf -e "mydestination = localhost"
postconf -e "inet_interfaces = loopback-only"
postconf -e "inet_protocols = ipv4"
postconf -e "relayhost ="
postconf -e "home_mailbox = Maildir/"

# Restart to apply
systemctl restart postfix
systemctl enable postfix

# Send test email
echo "Postfix installed on $FQDN" | mail -s "Test Email from $FQDN" root@localhost

echo "✅ Postfix installed and configured for send-only use"
echo "📤 To test: check /var/mail/root or send to an external address"
