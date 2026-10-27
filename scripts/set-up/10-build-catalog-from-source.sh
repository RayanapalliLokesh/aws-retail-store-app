#!/bin/bash
set -e

# Ensure Go binary path is included in PATH
export PATH=$PATH:/usr/local/go/bin

# 1. Build the catalog from source
cd ~/aws-retail-store-app/app/src/catalog
go mod download
go build -o ../../bin/catalog .

# 2. Return to root repository directory
cd ~/aws-retail-store-app

echo "Deploying retail-catalog binary and setting up systemd service..."

# 3. Ensure the retail system user and group exist (retail-catalog.service runs as User=retail)
if ! getent group retail >/dev/null; then
    sudo groupadd --system retail
fi
if ! getent passwd retail >/dev/null; then
    sudo useradd --system -g retail --home /opt/retail-store --shell /usr/sbin/nologin retail
fi

# 4. Stop a running copy, then install the binary where the unit's ExecStart expects it
sudo systemctl stop retail-catalog 2>/dev/null || true
sudo install -d -o retail -g retail -m 755 /opt/retail-store/catalog
sudo install -o retail -g retail -m 755 app/bin/catalog /opt/retail-store/catalog/catalog

# 5. Create config directory and install environment file (readable by the retail group)
sudo install -d -o root -g retail -m 750 /etc/retail-store
sudo install -o root -g retail -m 640 scripts/local/catalog.env /etc/retail-store/catalog.env

# 6. Install systemd service unit and start it
sudo install -m 644 scripts/systemd/retail-catalog.service /etc/systemd/system/retail-catalog.service
sudo systemctl daemon-reload
sudo systemctl enable --now retail-catalog

echo "retail-catalog successfully built, installed, and started!"