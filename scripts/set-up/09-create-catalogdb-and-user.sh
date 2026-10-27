#!/bin/bash
set -e

# 1. Navigate to the app directory
cd ~/aws-retail-store-app

# 2. Create the database and user properly for MariaDB
sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS catalog;

CREATE USER IF NOT EXISTS 'catalog_user'@'127.0.0.1' IDENTIFIED BY 'ChangeMe-Local-123';
CREATE USER IF NOT EXISTS 'catalog_user'@'localhost' IDENTIFIED BY 'ChangeMe-Local-123';

SET PASSWORD FOR 'catalog_user'@'127.0.0.1' = PASSWORD('ChangeMe-Local-123');
SET PASSWORD FOR 'catalog_user'@'localhost' = PASSWORD('ChangeMe-Local-123');

GRANT ALL PRIVILEGES ON catalog.* TO 'catalog_user'@'127.0.0.1';
GRANT ALL PRIVILEGES ON catalog.* TO 'catalog_user'@'localhost';
FLUSH PRIVILEGES;
EOF

sudo mysql < scripts/sql/catalog-db.sql
# test with the APPLICATION's credentials, over TCP, exactly as Catalog will connect
mysqladmin -ucatalog_user -p'ChangeMe-Local-123' -h127.0.0.1 ping
mysql -ucatalog_user -p'ChangeMe-Local-123' -h127.0.0.1 -e "SHOW DATABASES;"


