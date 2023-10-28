#!/bin/bash
#fail if any errors
set -e
set -o xtrace

sudo apt-get install -y zlib1g
# wget https://developer.nvidia.com/downloads/compute/cudnn/secure/8.9.5/local_installers/12.x/cudnn-local-repo-ubuntu2004-8.9.5.30_1.0-1_amd64.deb/
sudo dpkg -i ~/cudnn-local-repo-ubuntu2004-8.9.5.30_1.0-1_amd64.deb
sudo cp /var/cudnn-local-repo-*/cudnn-local-*-keyring.gpg /usr/share/keyrings/
sudo apt-get -y update
sudo apt-get -y install libcudnn8=8.9.5.30_1+cuda12.1
sudo apt-get -y install libcudnn8-dev=8.9.5.30_1+cuda12.1
sudo apt-get -y install libcudnn8-samples=8.9.5.30_1+cuda12.1
# rm ~/cudnn-local-repo-ubuntu2004-8.9.5.30_1.0-1_amd64.deb
