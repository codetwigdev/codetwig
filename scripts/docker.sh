#!/bin/bash
# docker.sh - Installs Docker and Docker Compose
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🐳 Installing Docker and Docker Compose..."

# Update and install dependencies
apt update && apt install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common \
  gnupg

# Add Docker GPG key and repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt update && apt install -y docker-ce docker-ce-cli containerd.io

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Install Docker Compose (v2 standalone)
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add user to docker group
if ! groups $USER | grep -q '\bdocker\b'; then
  usermod -aG docker $USER
  echo "ℹ️  You'll need to log out and back in to use Docker without sudo."
fi

# Verify
docker --version && docker-compose --version

echo "✅ Docker and Docker Compose installed successfully."
