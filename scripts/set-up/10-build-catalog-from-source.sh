#!/bin/bash

cd ~/aws-retail-store-app/app/src/catalog
go build -trimpath -o ~/aws-retail-store-app/app/bin/catalog . # downloads the Go modules the first time
ls -lh ~/aws-retail-store-app/app/bin/catalog
file ~/aws-retail-store-app/app/bin/catalog 2>/dev/null || true
