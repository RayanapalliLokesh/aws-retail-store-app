#!/bin/bash
# scripts/run-catalog-db.sh - start the Catalog datastore (MariaDB 10.9) in Docker.
# Published on 127.0.0.1:3306 only, so it is not reachable from outside the VM.
# Usage: export CATALOG_DB_PASSWORD=...   (typed in the terminal, never saved in a file)
#        ./scripts/run-catalog-db.sh
set -euo pipefail
: "${CATALOG_DB_PASSWORD:?export CATALOG_DB_PASSWORD first}"
docker rm -f catalog-db >/dev/null 2>&1 || true
docker run -d --name catalog-db -p 127.0.0.1:3306:3306 \
  -e MYSQL_ROOT_PASSWORD="$CATALOG_DB_PASSWORD" \
  -e MYSQL_DATABASE=catalogdb -e MYSQL_USER=catalog_user \
  -e MYSQL_PASSWORD="$CATALOG_DB_PASSWORD" \
  mariadb:10.9
echo "waiting for MariaDB ..."
for i in $(seq 1 30); do
  if docker exec catalog-db mysqladmin ping -h 127.0.0.1 --silent 2>/dev/null; then echo "catalog-db is up"; exit 0; fi
  sleep 2
done
echo "catalog-db did not become ready" >&2; exit 1
