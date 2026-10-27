#!/bin/bash

sudo mysql < scripts/sql/catalog-db.sql
# test with the APPLICATION's credentials, over TCP, exactly as Catalog will connect
mysqladmin -ucatalog_user -p'ChangeMe-Local-123' -h127.0.0.1 ping
mysql -ucatalog_user -p'ChangeMe-Local-123' -h127.0.0.1 -e "SHOW DATABASES;"


