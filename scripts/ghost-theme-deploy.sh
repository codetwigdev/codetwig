#!/bin/bash
# ghost-theme-deploy.sh - Deploy a custom Ghost theme from GitHub
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🎨 Ghost Theme Deployer"

# Prompt
read -p "Enter domain folder (e.g. /var/www/blog.example.com): " GHOST_DIR
read -p "Enter Git repo URL for the theme: " THEME_REPO
read -p "Enter theme folder name (e.g. codetwig-theme): " THEME_NAME

# Validate Ghost install
if [ ! -f "$GHOST_DIR/config.production.json" ]; then
  echo "❌ No Ghost installation found at $GHOST_DIR"
  exit 1
fi

# Go to themes directory
cd "$GHOST_DIR/content/themes"

# Remove existing theme if it exists
rm -rf "$THEME_NAME"

# Clone new theme
git clone "$THEME_REPO" "$THEME_NAME"
chown -R ghost:ghost "$THEME_NAME"

# Restart Ghost
cd "$GHOST_DIR"
ghost restart

echo "✅ Theme '$THEME_NAME' deployed and Ghost restarted."
echo "🧪 Visit your Ghost Admin > Design to activate the new theme."
