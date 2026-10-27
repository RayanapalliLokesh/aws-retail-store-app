#!/bin/bash

sudo apt update
sudo apt -y upgrade
sudo apt -y install curl wget unzip tar vim nano jq tree ca-certificates gnupg lsb-release

# verify
curl --version | head -n 1; jq --version; tree --version