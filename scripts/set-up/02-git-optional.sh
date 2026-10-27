#!/bin/bash
set -e

# 1. Install git if it is not already present
git --version || sudo apt-get -y install git
git --version

# 2. Configure the global git identity and defaults (re-running overwrites the same keys)
git config --global user.name "Rayanapalli Lokesh"
git config --global user.email "rayanapalli.lokesh@gmail.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor vim

# 3. Verify
git config --global --list
