#!/bin/bash

for u in 8888/actuator/health 8081/health 8082/actuator/health 8083/actuator/health 8085/health; do
 curl -s -o /dev/null -w "%{http_code} http://127.0.0.1:$u\n" --retry 20 --retry-delay 3 --retry-allerrors http://127.0.0.1:$u
done
systemctl is-active retail-catalog retail-cart retail-orders retail-checkout retail-ui mariadb redis-server
postgresql rabbitmq-server dynamodb-local
sudo ss -ltnp | grep -E ':(8081|8082|8083|8085|8888|3306|5432|6379|5672|8000) '