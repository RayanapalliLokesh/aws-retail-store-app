#!/bin/bash
set -e

# Stop the locally running services and remove the software installed by scripts 07-17.
# Nothing from scripts 01-06 is touched (base tools, git, SSH key, app source, Docker, compose stack).
# WARNING: the data of MariaDB, PostgreSQL, Redis, RabbitMQ and DynamoDB Local is deleted too.

read -p "This removes everything installed by scripts 07-17, including all data. Continue? [y/N] " reply
if [ "$reply" != "y" ] && [ "$reply" != "Y" ]; then
    echo "aborted"
    exit 1
fi

echo "1. Stopping and removing the retail-store services..."
for svc in ui orders cart checkout catalog; do
    sudo systemctl disable --now retail-$svc 2>/dev/null || true
    sudo rm -f /etc/systemd/system/retail-$svc.service
done
sudo rm -rf /opt/retail-store /etc/retail-store /var/log/retail-store
sudo userdel retail 2>/dev/null || true
sudo groupdel retail 2>/dev/null || true

echo "2. Removing DynamoDB Local..."
sudo systemctl disable --now dynamodb-local 2>/dev/null || true
sudo rm -f /etc/systemd/system/dynamodb-local.service
sudo rm -rf /opt/dynamodb-local
sudo userdel dynamodb 2>/dev/null || true
sudo groupdel dynamodb 2>/dev/null || true
sudo systemctl daemon-reload

echo "3. Removing Redis, PostgreSQL and RabbitMQ (with data)..."
sudo systemctl stop redis-server postgresql rabbitmq-server 2>/dev/null || true
sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y redis-server redis-tools postgresql postgresql-common rabbitmq-server || true
sudo rm -rf /var/lib/redis /etc/redis /var/log/redis
sudo rm -rf /var/lib/postgresql /etc/postgresql /etc/postgresql-common /var/log/postgresql
sudo rm -rf /var/lib/rabbitmq /etc/rabbitmq /var/log/rabbitmq

echo "4. Removing Java 21..."
sudo apt-get purge -y openjdk-21-jdk-headless openjdk-21-jre-headless || true

echo "5. Removing Node.js and Yarn..."
sudo rm -rf /usr/local/bin/node /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack
sudo rm -rf /usr/local/bin/yarn /usr/local/bin/yarnpkg
sudo rm -rf /usr/local/lib/node_modules /usr/local/include/node
sudo rm -rf /usr/local/share/doc/node /usr/local/share/man/man1/node.1
rm -rf ~/.npm ~/.cache/yarn

echo "6. Removing MariaDB (with the catalog database)..."
sudo systemctl stop mariadb 2>/dev/null || true
sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y mariadb-server mariadb-client mariadb-common || true
sudo rm -rf /var/lib/mysql /etc/mysql /var/log/mysql

echo "7. Removing Go and the Go module cache..."
sudo rm -rf /usr/local/go ~/go ~/.cache/go-build

echo "8. Removing build outputs (the source code in app/src is kept)..."
cd ~/aws-retail-store-app
rm -rf app/bin
rm -rf app/src/cart/target app/src/orders/target app/src/ui/target
rm -rf app/src/checkout/dist app/src/checkout/node_modules

echo "9. Removing unused dependencies..."
sudo apt-get autoremove -y

echo "10. Verify - none of these native-service ports should be listening:"
sudo ss -ltnp | grep -E ':(8081|8082|8083|8085|3306|5432|6379|5672|8000) ' || echo "none"
