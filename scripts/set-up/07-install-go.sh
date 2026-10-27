#!/bin/bash
set -e

GO_VERSION=1.24.7

# 1. Show the currently installed version (if any)
go version 2>/dev/null || echo "Go not installed"

# 2. Remove apt-installed Go so it cannot shadow /usr/local/go
sudo apt-get purge -y golang-go golang 2>/dev/null || true

# 3. Download, remove the old /usr/local/go and extract the new release
ARCH=$(dpkg --print-architecture) # amd64 or arm64
cd /tmp && curl -fsSLO https://go.dev/dl/go$GO_VERSION.linux-$ARCH.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go$GO_VERSION.linux-$ARCH.tar.gz && rm go$GO_VERSION.linux-$ARCH.tar.gz

# 4. Add Go to PATH for this shell
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

# 5. Verify
go version
