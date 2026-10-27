#!/bin/bash
set -e

DB_PASSWORD='ChangeMe-Local-123'

# 1. Remove previously installed versions (data directories are kept; users/db below are idempotent)
sudo systemctl stop redis-server postgresql rabbitmq-server 2>/dev/null || true
sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y redis-server redis-tools postgresql postgresql-common rabbitmq-server || true
sudo apt-get autoremove -y

# 2. Install Redis, PostgreSQL and RabbitMQ
sudo apt-get update
sudo apt-get -y install redis-server redis-tools postgresql rabbitmq-server

# 3. Enable and start the services
sudo systemctl enable --now redis-server postgresql rabbitmq-server

# 4. Verify
systemctl is-active redis-server postgresql rabbitmq-server
redis-cli ping
sudo -u postgres psql -tAc "select version();" | cut -c1-30
sudo rabbitmqctl status | grep -m1 "RabbitMQ version"

# 5. PostgreSQL: user orders_user, database orders (created only if missing, password always reset)
sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'orders_user') THEN
    CREATE ROLE orders_user LOGIN;
  END IF;
END \$\$;
ALTER ROLE orders_user WITH PASSWORD '$DB_PASSWORD';
SELECT 'CREATE DATABASE orders OWNER orders_user' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'orders')\gexec
SQL
PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U orders_user -d orders -tAc 'select 1;' # 1

# 6. RabbitMQ: user rabbitmq with full rights on the default vhost
if sudo rabbitmqctl list_users -q | grep -q '^rabbitmq\b'; then
    sudo rabbitmqctl change_password rabbitmq "$DB_PASSWORD"
else
    sudo rabbitmqctl add_user rabbitmq "$DB_PASSWORD"
fi
sudo rabbitmqctl set_permissions -p / rabbitmq '.*' '.*' '.*'
sudo rabbitmqctl authenticate_user rabbitmq "$DB_PASSWORD"

# 7. Redis: nothing to create - Checkout uses one key per customer in database 0
