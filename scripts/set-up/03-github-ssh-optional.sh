#!/bin/bash
set -e

# 1. Install the OpenSSH client if it is not already present
command -v ssh-keygen || sudo apt-get -y install openssh-client
ssh -V

# 2. Generate an ed25519 key only if one does not exist yet (never overwrite an existing key)
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -C "rayanapalli.lokesh@gmail.com" # accept the default path, set a passphrase
else
    echo "~/.ssh/id_ed25519 already exists - reusing it"
fi
cat ~/.ssh/id_ed25519.pub

# 3. GitHub -> Settings -> SSH and GPG keys -> New SSH key -> paste the line printed above
#    ssh -T always exits 1 (GitHub gives no shell), so don't let set -e stop here
ssh -T git@github.com || true
