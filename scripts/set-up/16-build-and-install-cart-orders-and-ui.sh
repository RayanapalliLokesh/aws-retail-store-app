#!/bin/bash

cd ~/aws-retail-store-app
for svc in cart orders ui; do
 (cd app/src/$svc && ./mvnw -B -q -DskipTests package)
 jar=$(ls app/src/$svc/target/*.jar | grep -v original | head -n 1); echo "$svc -> $jar"
 sudo install -d -o retail -g retail -m 755 /opt/retail-store/$svc
 sudo install -o retail -g retail -m 644 "$jar" /opt/retail-store/$svc/app.jar
 sudo install -o root -g retail -m 640 scripts/local/$svc.env /etc/retail-store/$svc.env
 sudo install -m 644 scripts/systemd/retail-$svc.service /etc/systemd/system/
done
sudo systemctl daemon-reload

sudo sed -i 's/^RETAIL_CART_PERSISTENCE_DYNAMODB_CREATE_TABLE=.*/RETAIL_CART_PERSISTENCE_DYNAMODB_CREATE_TABLE=true/' /etc/retail-store/cart.env
sudo systemctl enable --now retail-cart
until curl -sf -o /dev/null http://127.0.0.1:8082/actuator/health; do sleep 3; done; echo "cart up, table
created"
sudo sed -i 's/^RETAIL_CART_PERSISTENCE_DYNAMODB_CREATE_TABLE=.*/RETAIL_CART_PERSISTENCE_DYNAMODB_CREATE_TABLE=false/' /etc/retail-store/cart.env
sudo systemctl restart retail-cart
sudo systemctl enable --now retail-orders retail-ui

