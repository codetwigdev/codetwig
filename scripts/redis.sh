#!/bin/bash
# redis.sh - Install Redis Server with systemd
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "⚡ Installing Redis..."

# Update and install Redis
apt update && apt install -y redis-server

# Enable Redis to start on boot
systemctl enable redis-server
systemctl start redis-server

# Secure Redis (bind to localhost, require password)
REDIS_PASS=$(openssl rand -base64 16)
sed -i "s/^# requirepass .*/requirepass $REDIS_PASS/" /etc/redis/redis.conf
sed -i "s/^bind 127.0.0.1 ::1/bind 127.0.0.1/" /etc/redis/redis.conf
sed -i "s/^# maxmemory .*/maxmemory 256mb/" /etc/redis/redis.conf
sed -i "s/^# maxmemory-policy .*/maxmemory-policy allkeys-lru/" /etc/redis/redis.conf

# Restart to apply
systemctl restart redis-server

# Test
echo "PING with auth..."
redis-cli -a "$REDIS_PASS" ping

# Save credentials
echo "$REDIS_PASS" > /root/redis_password.txt

echo "✅ Redis installed and secured with password"
echo "🔐 Password saved to /root/redis_password.txt"
