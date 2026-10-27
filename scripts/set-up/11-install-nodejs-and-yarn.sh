#!/bin/bash
set -e

NODE_VERSION=22.22.0
YARN_VERSION=1.22.22

# 1. Show the currently installed version (if any)
node -v 2>/dev/null || echo "Node not installed"

# 2. Remove apt-installed Node.js/Yarn and any previous tarball install in /usr/local
sudo apt-get purge -y nodejs npm yarn 2>/dev/null || true
sudo rm -rf /usr/local/bin/node /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
            /usr/local/bin/yarn /usr/local/bin/yarnpkg \
            /usr/local/lib/node_modules /usr/local/include/node \
            /usr/local/share/doc/node /usr/local/share/man/man1/node.1
hash -r

# 3. Download and extract Node.js into /usr/local
ARCH=$(uname -m | sed 's/x86_64/x64/; s/aarch64/arm64/')
cd /tmp && curl -fsSLO https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz
sudo tar -C /usr/local --strip-components=1 -xJf node-v$NODE_VERSION-linux-$ARCH.tar.xz && rm node-v$NODE_VERSION-linux-$ARCH.tar.xz

# 4. Install Yarn classic globally
sudo npm install -g yarn@$YARN_VERSION

# 5. Make sure /usr/local/bin is on PATH for this shell, then verify
export PATH=/usr/local/bin:$PATH
node -v; npm -v; yarn -v
