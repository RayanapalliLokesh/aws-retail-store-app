#!/bin/bash
# scripts/remote-client-test.sh - test a port "from another machine".
# Runs a throw-away container (its own network namespace, so its 127.0.0.1 is NOT this VM)
# and sends GET /actuator/health to HOST:PORT. From a container this VM is 172.17.0.1 (docker0).
# Usage: ./scripts/remote-client-test.sh 172.17.0.1 8080
# Prints the HTTP status line, or "FAILED" with the connection error.
set -uo pipefail
HOST="${1:?usage: $0 HOST PORT}"; PORT="${2:?usage: $0 HOST PORT}"
docker run --rm mariadb:10.9 bash -c "timeout 3 bash -c 'exec 3<>/dev/tcp/$HOST/$PORT && printf \"GET /actuator/health HTTP/1.0\r\nHost: x\r\n\r\n\" >&3 && head -1 <&3' 2>&1 || echo 'FAILED (exit '\$?')'"
