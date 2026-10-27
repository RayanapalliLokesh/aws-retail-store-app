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

# 4. Pull missing images one at a time, retrying on rate limits
# Anonymous pulls from public.ecr.aws are rate-limited per source IP. Shared
# hosts (e.g. KodeKloud playgrounds) share outbound IPs with other users, so
# pulls can fail with "toomanyrequests: Rate exceeded" even when pulling one
# image at a time. The limit resets quickly, so wait 30s and retry; images
# already pulled are skipped. Logging in to ECR Public raises the limit:
#   aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws
for img in $(docker compose config --images); do
    docker image inspect "$img" >/dev/null 2>&1 && continue
    for i in $(seq 1 10); do
        docker pull "$img" && break
        [ "$i" -eq 10 ] && { echo "giving up on $img"; exit 1; }
        echo "rate limited on $img, retry $i/10 in 30s"; sleep 30
    done
done

# 5. Start the stack (all images are local now, so nothing is pulled here)
docker compose up -d --wait --wait-timeout 900

# 6. Verify
docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'

# NOTE: the compose UI publishes port 8888, the same port the native retail-ui uses.
# Stop this stack before script 16:  cd ~/aws-retail-store-app/deploy/compose-full && docker compose down
