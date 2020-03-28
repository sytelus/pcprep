#!/bin/bash
#fail if any errors
set -e
set -o xtrace


# kubectl
sudo apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
#echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
FILE=~/etc/apt/sources.list.d/kubernetes.list
LINE='deb https://apt.kubernetes.io/ kubernetes-xenial main'
grep -q "$LINE" "$FILE" || sudo echo "$LINE" >> "$FILE"sudo apt-get update
sudo apt-get install -y kubectl
