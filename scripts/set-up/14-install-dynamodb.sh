#!/bin/bash
set -e

# 1. Navigate to the app directory where systemd service templates are located
cd ~/aws-retail-store-app

# 2. Create system user and target directory if they don't exist
sudo id -u dynamodb &>/dev/null || sudo useradd --system --home /opt/dynamodb-local --shell /usr/sbin/nologin dynamodb
sudo mkdir -p /opt/dynamodb-local

# 3. Stop a running instance and remove the old release (the shared-local-instance.db data file is kept)
sudo systemctl stop dynamodb-local 2>/dev/null || true
sudo rm -rf /opt/dynamodb-local/DynamoDBLocal.jar /opt/dynamodb-local/DynamoDBLocal_lib

# 4. Download and extract DynamoDB Local correctly in a single command pipeline
curl -fsSL https://d1ni2b6xgvw0s0.cloudfront.net/v2.x/dynamodb_local_latest.tar.gz | sudo tar -xz -C /opt/dynamodb-local

# 5. Set correct ownership
sudo chown -R dynamodb:dynamodb /opt/dynamodb-local

# 6. Install systemd service and start the service
sudo install -m 644 scripts/systemd/dynamodb-local.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now dynamodb-local

# 7. Verify health check
sleep 5
curl -s -o /dev/null -w 'dynamodb-local HTTP %{http_code}\n' http://127.0.0.1:8000