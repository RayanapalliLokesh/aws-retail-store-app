#!/bin/bash

cd ~/aws-retail-store-app
git clone --depth 1 --branch v1.3.0 https://github.com/aws-containers/retail-store-sample-app.git /tmp/rs
mkdir -p app && cp -r /tmp/rs/src app/ && rm -rf /tmp/rs
ls app/src
du -sh app && git status --short | head -n 3