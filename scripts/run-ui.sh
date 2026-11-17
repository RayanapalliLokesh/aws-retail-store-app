#!/bin/bash
# scripts/run-ui.sh - run the UI service (Spring Boot jar) directly on Ubuntu.
# Usage: ./scripts/run-ui.sh [bind-address] [port] [catalog-url]
#   bind-address  0.0.0.0 (default) or 127.0.0.1
#   catalog-url   default http://localhost:8081 ; pass "" to let the UI use its built-in mock catalog
# Build once: cd app/src/ui && ./mvnw -DskipTests package
set -euo pipefail
source "$(dirname "$0")/env.sh"
BIND="${1:-0.0.0.0}"
PORT_ARG="${2:-8080}"
CATALOG_URL="${3-http://localhost:8081}"
RETAIL_UI_ENDPOINTS_CATALOG="$CATALOG_URL" \
  nohup java -jar "$REPO_DIR/app/src/ui/target/ui-0.0.1-SNAPSHOT.jar" \
  --server.address="$BIND" --server.port="$PORT_ARG" >> "$LOG_DIR/ui.log" 2>&1 &
echo "ui started, PID $!, bind $BIND:$PORT_ARG, catalog '${CATALOG_URL}', log $LOG_DIR/ui.log"
