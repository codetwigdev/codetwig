#!/bin/bash
# mariadb.sh - Install and secure MariaDB with optional DB/user setup
# Author: CodeTwig
# Updated: 2025-05-23

set -e

echo "🛢️  Installing MariaDB..."

# Install MariaDB
apt update && apt install -y mariadb-server

# Enable and start
systemctl enable mariadb
systemctl start mariadb

# Secure MariaDB
echo "🔐 Securing MariaDB..."

MYSQL_ROOT_PASS=$(openssl rand -base64 12)

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

echo "✅ Root password set and insecure defaults removed"
echo "🔐 Root password saved to /root/mariadb_root.txt"
echo "$MYSQL_ROOT_PASS" > /root/mariadb_root.txt

# Prompt to create a new DB + user
read -p "Create a new database and user? (y/N): " CREATE_DB
if [[ "$CREATE_DB" =~ ^[Yy]$ ]]; then
  read -p "Enter database name: " DB_NAME
  read -p "Enter new database user: " DB_USER
  DB_PASS=$(openssl rand -base64 12)

  mysql -uroot -p"$MYSQL_ROOT_PASS" <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

  echo "✅ Created DB: $DB_NAME with user: $DB_USER"
  echo "User password: $DB_PASS" > /root/mariadb_user_${DB_NAME}.txt
fi
