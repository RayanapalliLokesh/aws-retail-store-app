#!/bin/bash
set -e

APP_VERSION=v1.3.0

# 1. Navigate to the app directory
cd ~/aws-retail-store-app

# 2. Skip the import if the source is already there (delete app/src first to re-import)
if [ -d app/src ]; then
    echo "app/src already exists - skipping import (rm -rf app/src to re-import $APP_VERSION)"
    ls app/src
    exit 0
fi

# 3. Clone the upstream release into a clean temp dir and copy only src/
rm -rf /tmp/rs
git clone --depth 1 --branch $APP_VERSION https://github.com/aws-containers/retail-store-sample-app.git /tmp/rs
mkdir -p app && cp -r /tmp/rs/src app/ && rm -rf /tmp/rs

# 4. Verify
ls app/src
du -sh app && git status --short | head -n 3
