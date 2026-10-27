#!/bin/bash
set -e

# 1. Refresh package lists and upgrade the system
sudo apt-get update
sudo apt-get -y upgrade

# 2. Install the base tools used by the later scripts
#    (apt-get install is idempotent - already installed tools are kept or upgraded)
sudo apt-get -y install curl wget unzip tar vim nano jq tree ca-certificates gnupg lsb-release

# 3. Verify
curl --version | head -n 1; jq --version; tree --version
