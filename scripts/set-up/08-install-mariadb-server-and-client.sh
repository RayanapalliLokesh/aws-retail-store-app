#!/bin/bash

sudo apt -y install mariadb-server mariadb-client
sudo systemctl enable --now mariadb
systemctl is-active mariadb 
sudo mysql -e "SELECT VERSION();" 
sudo ss -ltnp | grep 3306 