#!/bin/bash

node -v 2>/dev/null || echo "Node not installed"
NODE_VERSION=22.22.0
ARCH=$(uname -m | sed 's/x86_64/x64/; s/aarch64/arm64/')
cd /tmp && curl -fsSLO https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz
sudo tar -C /usr/local --strip-components=1 -xJf node-v$NODE_VERSION-linux-$ARCH.tar.xz && rm nodev$NODE_VERSION-linux-$ARCH.tar.xz
sudo npm install -g yarn@1.22.22
node -v; npm -v; yarn -v
