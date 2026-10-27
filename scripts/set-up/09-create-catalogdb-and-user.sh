#!/bin/bash
set -e

# 1. Navigate to the app directory
cd ~/aws-retail-store-app

# 2. Create the database and user (must match scripts/local/catalog.env)
sudo mysql < scripts/sql/catalog-db.sql

# 3. test with the APPLICATION's credentials, over TCP, exactly as Catalog will connect
mysqladmin -ucatalog_user -p'Lokesh@312' -h127.0.0.1 ping
mysql -ucatalog_user -p'Lokesh@312' -h127.0.0.1 -e "SHOW DATABASES;"
