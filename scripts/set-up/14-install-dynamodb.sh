#!/bin/bash

sudo useradd --system --home /opt/dynamodb-local --shell /usr/sbin/nologin dynamodb
sudo mkdir -p /opt/dynamodb-local
curl -fsSL https://d1ni2b6xgvw0s0.cloudfront.net/v2.x/dynamodb_local_latest.tar.gz | sudo tar -xz -C
/opt/dynamodb-local
sudo chown -R dynamodb:dynamodb /opt/dynamodb-local
ls /opt/dynamodb-local 

sudo install -m 644 scripts/systemd/dynamodb-local.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now dynamodb-local
sleep 5; curl -s -o /dev/null -w 'dynamodb-local HTTP %{http_code}\n' http://127.0.0.1:8000