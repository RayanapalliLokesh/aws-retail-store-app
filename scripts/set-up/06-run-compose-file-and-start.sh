#!/bin/bash
set -e

# 1. Navigate to the app directory and download the release compose file
cd ~/aws-retail-store-app
mkdir -p deploy/compose-full docs/evidence
curl -fsSL -o deploy/compose-full/docker-compose.yaml \
 https://github.com/aws-containers/retail-store-sample-app/releases/download/v1.3.0/docker-compose.yaml
grep -c "image:" deploy/compose-full/docker-compose.yaml # 10 services
cd deploy/compose-full

# 2. Database password used by the compose services
export DB_PASSWORD='ChangeMe-Local-123'

# 3. Remove a previously started stack (containers + volumes) before starting fresh
docker compose down -v --remove-orphans || true

# 4. Start the stack
# Limit parallel downloads to prevent AWS ECR public rate limiting,
# and optionally log in to public ECR if you have an account.
COMPOSE_PARALLEL_LIMIT=1 docker compose up -d --wait --wait-timeout 900

# for parallel downloads, you can also use:
# docker compose up -d --wait --wait-timeout 900

# 5. Verify
docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'

# NOTE: the compose UI publishes port 8888, the same port the native retail-ui uses.
# Stop this stack before script 16:  cd ~/aws-retail-store-app/deploy/compose-full && docker compose down
