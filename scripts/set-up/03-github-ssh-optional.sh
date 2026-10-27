#!/bin/bash

command -v ssh-keygen || sudo apt -y install openssh-client
ssh -V

ssh-keygen -t ed25519 -C "rayanapalli.lokesh@gmail.com" # accept the default path, set a passphrase
cat ~/.ssh/id_ed25519.pub

# GitHub -> Settings -> SSH and GPG keys -> New SSH key -> paste the line printed above
ssh -T git@github.com 