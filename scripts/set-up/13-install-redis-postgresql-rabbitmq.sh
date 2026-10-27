#!/bin/bash

sudo apt -y install redis-server redis-tools postgresql rabbitmq-server
sudo systemctl enable --now redis-server postgresql rabbitmq-server
systemctl is-active redis-server postgresql rabbitmq-server
redis-cli ping 
sudo -u postgres psql -tAc "select version();" | cut -c1-30
sudo rabbitmqctl status | grep -m1 "RabbitMQ version"

# PostgreSQL: user orders_user, database orders
sudo -u postgres psql -c "CREATE USER orders_user WITH PASSWORD 'ChangeMe-Local-123';"
sudo -u postgres psql -c "CREATE DATABASE orders OWNER orders_user;"
PGPASSWORD='ChangeMe-Local-123' psql -h 127.0.0.1 -U orders_user -d orders -tAc 'select 1;' # 1

# RabbitMQ: user rabbitmq with full rights on the default vhost
sudo rabbitmqctl add_user rabbitmq 'ChangeMe-Local-123'
sudo rabbitmqctl set_permissions -p / rabbitmq '.*' '.*' '.*'
sudo rabbitmqctl authenticate_user rabbitmq 'ChangeMe-Local-123'
# Redis: nothing to create - Checkout uses one key per customer in database 0