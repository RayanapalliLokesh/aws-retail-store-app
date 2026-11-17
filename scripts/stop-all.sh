#!/bin/bash
# scripts/stop-all.sh - stop UI, Catalog and the Catalog datastore.
# Note: avoid plain "pkill -f <word>" - it also matches any shell whose command line contains <word>.
pkill -f '^java -jar .*/ui-0\.0\.1-SNAPSHOT\.jar' && echo "ui stopped"
pkill -x catalog && echo "catalog stopped"
docker rm -f catalog-db >/dev/null 2>&1 && echo "catalog-db removed"
exit 0
