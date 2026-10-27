#!/bin/bash
set -e

# 1. HTTP health checks (ui, catalog, cart, orders, checkout) - report failures, don't stop
for u in 8888/actuator/health 8081/health 8082/actuator/health 8083/actuator/health 8085/health; do
    curl -s -o /dev/null -w "%{http_code} http://127.0.0.1:$u\n" --retry 20 --retry-delay 3 --retry-all-errors http://127.0.0.1:$u || echo "FAIL http://127.0.0.1:$u"
done

# 2. systemd state of every app service and backing store
systemctl is-active retail-catalog retail-cart retail-orders retail-checkout retail-ui \
    mariadb redis-server postgresql rabbitmq-server dynamodb-local || true

# 3. Listening ports
sudo ss -ltnp | grep -E ':(8081|8082|8083|8085|8888|3306|5432|6379|5672|8000) ' || true
