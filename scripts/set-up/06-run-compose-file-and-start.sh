#!/bin/bash

cd ~/aws-retail-store-app
mkdir -p deploy/compose-full docs/evidence
curl -fsSL -o deploy/compose-full/docker-compose.yaml \
 https://github.com/aws-containers/retail-store-sample-app/releases/download/v1.3.0/docker-compose.yaml
grep -c "image:" deploy/compose-full/docker-compose.yaml # 10 services
cd deploy/compose-full
DB_PASSWORD='ChangeMe-Local-123' docker compose up -d --wait --wait-timeout 900
docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'