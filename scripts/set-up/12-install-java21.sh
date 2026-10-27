#!/bin/bash
set -e

echo "1. Purging broken Java installations and cleaning package state..."
sudo apt-get purge -y openjdk-21-jdk-headless openjdk-21-jre-headless || true
sudo apt-get autoremove -y

echo "2. Ensuring required documentation directories exist..."
sudo mkdir -p /usr/share/man/man1

echo "3. Re-installing Java 21 cleanly..."
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk-headless

echo "4. Verifying installation..."
java -version 2>&1 | head -n 1