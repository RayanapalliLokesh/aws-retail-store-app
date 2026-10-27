#!/bin/bash
set -e

# 1. Ensure the retail system user and group exist
if ! getent group retail >/dev/null; then
    sudo groupadd --system retail
fi
if ! getent passwd retail >/dev/null; then
    sudo useradd --system -g retail --home /opt/retail-store --shell /usr/sbin/nologin retail
fi

# 2. Build the checkout service
cd ~/aws-retail-store-app/app/src/checkout
yarn install --frozen-lockfile && yarn build

# 3. Create deployment directories with correct ownership and permissions
cd ~/aws-retail-store-app
sudo install -d -o retail -g retail -m 755 /opt/retail-store/checkout
sudo systemctl stop retail-checkout 2>/dev/null || true
sudo rm -rf /opt/retail-store/checkout/dist /opt/retail-store/checkout/node_modules

# 4. Copy build artifacts and dependencies using consistent paths
sudo cp -r app/src/checkout/dist app/src/checkout/package.json app/src/checkout/node_modules /opt/retail-store/checkout/
sudo chown -R retail:retail /opt/retail-store/checkout

# 5. Create config directory and install environment variables file
sudo install -d -o root -g retail -m 750 /etc/retail-store
sudo install -o root -g retail -m 640 scripts/local/checkout.env /etc/retail-store/checkout.env

# 6. Install systemd service and start service
sudo install -m 644 scripts/systemd/retail-checkout.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now retail-checkout

# 7. Verify health check
sleep 5
curl -s -o /dev/null -w 'checkout health %{http_code}\n' http://127.0.0.1:8085/health