#!/bin/bash

cd ~/aws-retail-store-app/app/src/checkout
yarn install --frozen-lockfile && yarn build
cd ~/aws-retail-store-app
sudo install -d -o retail -g retail -m 755 /opt/retail-store/checkout
sudo rm -rf /opt/retail-store/checkout/dist
sudo cp -r app/src/checkout/dist app/src/checkout/package.json app/src/checkout/node_modules /opt/retailstore/checkout/
sudo chown -R retail:retail /opt/retail-store/checkout
sudo install -o root -g retail -m 640 scripts/local/checkout.env /etc/retail-store/checkout.env
sudo install -m 644 scripts/systemd/retail-checkout.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now retail-checkout
sleep 5; curl -s -o /dev/null -w 'checkout health %{http_code}\n' http://127.0.0.1:8085/health
