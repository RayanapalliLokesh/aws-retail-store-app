#!/bin/bash

# 1. remove old or conflicting packages (ignore "not installed" messages)
for p in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt -y remove $p
2>/dev/null; done

# 2. add Docker's signing key and repository
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc]
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-
$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 3. install
sudo apt update
sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker

# 4. run docker without sudo (log out and back in, or use newgrp for this shell)
sudo usermod -aG docker $USER
newgrp docker

# 5. verify
docker --version; docker compose version
docker run --rm hello-world | grep "Hello from Docker"