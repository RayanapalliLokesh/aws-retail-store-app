#!/bin/bash
set -e

# 1. Java environment for the Maven wrapper (JDK installed by script 12)
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export PATH=$JAVA_HOME/bin:$PATH
java -version 2>&1 | head -n 1

# 2. Ensure the retail system user and group exist
if ! getent group retail >/dev/null; then
    sudo groupadd --system retail
fi
if ! getent passwd retail >/dev/null; then
    sudo useradd --system -g retail --home /opt/retail-store --shell /usr/sbin/nologin retail
fi
sudo install -d -o root -g retail -m 750 /etc/retail-store

# 3. Build each service, stage its jar as app/bin/<svc>/app.jar, stop the running copy,
#    and install the new jar, env file and unit
cd ~/aws-retail-store-app
for svc in cart orders ui; do
    (cd app/src/$svc && ./mvnw -B -q -DskipTests clean package)
    jar=$(ls app/src/$svc/target/*.jar | grep -v original | head -n 1); echo "$svc -> $jar"
    mkdir -p app/bin/$svc
    cp "$jar" app/bin/$svc/app.jar

    sudo systemctl stop retail-$svc 2>/dev/null || true
    sudo rm -f /opt/retail-store/$svc/app.jar

    sudo install -d -o retail -g retail -m 755 /opt/retail-store/$svc
    sudo install -o retail -g retail -m 644 app/bin/$svc/app.jar /opt/retail-store/$svc/app.jar
    sudo install -o root -g retail -m 640 scripts/local/$svc.env /etc/retail-store/$svc.env
    sudo install -m 644 scripts/systemd/retail-$svc.service /etc/systemd/system/
done
sudo systemctl daemon-reload

# 4. Start Cart once with CREATE_TABLE=true so it creates the DynamoDB table, then switch it back
sudo sed -i 's/^RETAIL_CART_PERSISTENCE_DYNAMODB_CREATE_TABLE=.*/RETAIL_CART_PERSISTENCE_DYNAMODB_CREATE_TABLE=true/' /etc/retail-store/cart.env
sudo systemctl enable --now retail-cart
timeout 300 bash -c 'until curl -sf -o /dev/null http://127.0.0.1:8082/actuator/health; do sleep 3; done'
echo "cart up, table created"
sudo sed -i 's/^RETAIL_CART_PERSISTENCE_DYNAMODB_CREATE_TABLE=.*/RETAIL_CART_PERSISTENCE_DYNAMODB_CREATE_TABLE=false/' /etc/retail-store/cart.env
sudo systemctl restart retail-cart

# 5. Start Orders and UI
sudo systemctl enable --now retail-orders retail-ui

# 6. Verify
systemctl is-active retail-cart retail-orders retail-ui
