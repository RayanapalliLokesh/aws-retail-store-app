#!/bin/bash
set -e

# 1. remove old or conflicting packages (ignore "not installed" messages)
for p in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get -y remove $p 2>/dev/null || true
done

# 2. add Docker's signing key and repository
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 3. install
sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable containerd docker
sudo systemctl restart containerd docker   # pick up upgraded binaries if they were already running

# 4. run docker without sudo (takes effect after you log out and back in)
sudo usermod -aG docker $USER

# 5. verify - sg runs the commands with the new docker group without a re-login
#    (newgrp would open a new shell and stop this script)
sg docker -c 'docker --version; docker compose version'
sg docker -c 'docker run --rm hello-world' | grep "Hello from Docker"
