#!/bin/bash
# scripts/run-catalog.sh - run the Catalog service (Go binary) directly on Ubuntu.
# Usage: ./scripts/run-catalog.sh [port]      default port 8081
# Build once: cd app/src/catalog && go build -o ../../bin/catalog .
set -euo pipefail
source "$(dirname "$0")/env.sh"
: "${CATALOG_DB_PASSWORD:?export CATALOG_DB_PASSWORD first}"
PORT_ARG="${1:-8081}"
PORT="$PORT_ARG" GIN_MODE=release \
RETAIL_CATALOG_PERSISTENCE_PROVIDER=mysql \
RETAIL_CATALOG_PERSISTENCE_ENDPOINT=127.0.0.1:3306 \
RETAIL_CATALOG_PERSISTENCE_PASSWORD="${CATALOG_DB_PASSWORD}" \
  nohup "$REPO_DIR/app/bin/catalog" >> "$LOG_DIR/catalog.log" 2>&1 &
echo "catalog started, PID $!, port $PORT_ARG, log $LOG_DIR/catalog.log"
