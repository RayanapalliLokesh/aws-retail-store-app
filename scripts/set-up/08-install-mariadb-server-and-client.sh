#!/bin/bash
set -e

# 1. Remove any existing MariaDB/MySQL packages (databases in /var/lib/mysql are kept)
sudo systemctl stop mariadb 2>/dev/null || true
sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y mariadb-server mariadb-client mysql-server mysql-client || true
sudo apt-get autoremove -y

# 2. Install MariaDB server and client
sudo apt-get update
sudo apt-get -y install mariadb-server mariadb-client

# 3. Enable and start the service
sudo systemctl enable --now mariadb

# 4. Verify
systemctl is-active mariadb
sudo mysql -e "SELECT VERSION();"
sudo ss -ltnp | grep 3306
