#!/bin/bash
# portainer.sh - Install Portainer (Docker Management UI)
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "📦 Installing Portainer..."

# Prompt for port
read -p "Enter the port to run Portainer on (default: 9000): " PORT
PORT=${PORT:-9000}

# Create volume
docker volume create portainer_data

# Run Portainer container
docker run -d \
  -p $PORT:9000 \
  --name=portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

echo "✅ Portainer is running at http://<your-server-ip>:$PORT"
echo "🌐 Open in your browser and create the admin account."
