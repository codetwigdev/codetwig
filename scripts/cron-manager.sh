#!/bin/bash
# cron-manager.sh - Simple CLI to manage cron jobs
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🕒 CodeTwig Cron Manager"
echo "========================"
echo "1) View current cron jobs"
echo "2) Add a new cron job"
echo "3) Exit"
read -p "Choose an option [1-3]: " OPTION

case $OPTION in
  1)
    echo "📋 Current user cron jobs:"
    crontab -l || echo "No cron jobs found."
    ;;
  2)
    echo "🛠 Add a new cron job"
    read -p "Enter the schedule (e.g. '0 3 * * *'): " SCHEDULE
    read -p "Enter the command to run: " COMMAND
    (crontab -l 2>/dev/null; echo "$SCHEDULE $COMMAND") | crontab -
    echo "✅ Cron job added."
    ;;
  3)
    echo "Goodbye!"
    exit 0
    ;;
  *)
    echo "❌ Invalid option"
    ;;
esac
