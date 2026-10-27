#!/bin/bash

go version 2>/dev/null || echo "Go not installed"
ARCH=$(dpkg --print-architecture) # amd64 or arm64
cd /tmp && curl -fsSLO https://go.dev/dl/go1.24.7.linux-$ARCH.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.24.7.linux-$ARCH.tar.gz && rm
go1.24.7.linux-$ARCH.tar.gz
grep -q '/usr/local/go/bin' ~/.bashrc || echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
source ~/.bashrc
go version

