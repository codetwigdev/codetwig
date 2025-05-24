#!/bin/bash
# uptime-kuma.sh - Deploy Uptime Kuma with Docker
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "📈 Installing Uptime Kuma monitoring dashboard..."

# Prompt for port
read -p "Enter the port to run Uptime Kuma on (default: 3001): " PORT
PORT=${PORT:-3001}

# Create volume
mkdir -p /opt/uptime-kuma

# Run with Docker
docker run -d \
  --restart=always \
  --name uptime-kuma \
  -p $PORT:3001 \
  -v /opt/uptime-kuma:/app/data \
  louislam/uptime-kuma:latest

echo "✅ Uptime Kuma is running on http://<your-server-ip>:$PORT"
echo "🌐 To access it, open your browser and set up the admin account."
