#!/bin/bash

git --version || sudo apt -y install git
git --version

git config --global user.name "Rayanapalli Lokesh"
git config --global user.email "rayanapalli.lokesh@gmail.com"
git config --global init.defaultBranch main
git config --global pull.rebase false 
git config --global core.editor vim 
git config --global --list
