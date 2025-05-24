#!/bin/bash
# ngrok.sh - Installs Ngrok and prompts for tunnel setup
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🌍 Installing Ngrok CLI..."

# Prompt for auth token and port
read -p "Enter your Ngrok auth token (from https://dashboard.ngrok.com/get-started): " TOKEN
read -p "Enter local port to expose (e.g. 3000): " PORT

# Download and install Ngrok
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list
apt update && apt install -y ngrok

# Auth and run tunnel
ngrok config add-authtoken $TOKEN

echo "📡 Starting Ngrok tunnel to port $PORT..."
ngrok http $PORT
