#!/usr/bin/env bash

# scripts/deploy-catalog.sh - install the Catalog binary, env file and systemd unit (run with sudo).
# Prerequisites: Go build done (app/bin/catalog) and MariaDB set up (Task 4, Step B2-B3).

set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run as root: sudo $0" >&2; exit 1; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "[1/5] service account 'retail' (no login shell)"
id retail >/dev/null 2>&1 || useradd --system --user-group --home-dir /opt/retail-store --shell /usr/sbin/nologin retail

echo "[2/5] directories"
install -d -o root -g root -m 755 /opt/retail-store
install -d -o retail -g retail -m 755 /opt/retail-store/catalog
install -d -o root -g retail -m 750 /etc/retail-store
install -d -o retail -g retail -m 755 /var/log/retail-store

echo "[3/5] binary"
[[ -x "$REPO/app/bin/catalog" ]] || { echo "build first (Step B4)" >&2; exit 1; }
install -o retail -g retail -m 755 "$REPO/app/bin/catalog" /opt/retail-store/catalog/catalog

echo "[4/5] configuration (root:retail 640 - the service can read it, other users cannot)"
install -o root -g retail -m 640 "$REPO/scripts/local/catalog.env" /etc/retail-store/catalog.env

echo "[5/5] systemd unit"
install -o root -g root -m 644 "$REPO/scripts/systemd/retail-catalog.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now retail-catalog.service
systemctl restart retail-catalog.service
sleep 3
systemctl --no-pager status retail-catalog | head -n 5
