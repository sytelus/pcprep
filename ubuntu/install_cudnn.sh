#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# WARNING: Do not update below to new version. There is no 12.1 cuda package after cudnn 8.9.3.28
# To see available packages run:
# sudo apt-cache madison libcudnn8

sudo apt-get install -y zlib1g
# wget https://developer.nvidia.com/downloads/compute/cudnn/secure/8.9.3/local_installers/12.x/cudnn-local-repo-ubuntu2004-8.9.3.28_1.0-1_amd64.deb/
sudo dpkg -i ~/cudnn-local-repo-ubuntu2004-8.9.3.28_1.0-1_amd64.deb
sudo cp /var/cudnn-local-repo-*/cudnn-local-*-keyring.gpg /usr/share/keyrings/
sudo apt-get -y update
sudo apt-get -y install libcudnn8=8.9.3.28-1+cuda12.1
sudo apt-get -y install libcudnn8-dev=8.9.3.28-1+cuda12.1
sudo apt-get -y install libcudnn8-samples=8.9.3.28-1+cuda12.1
# rm ~/cudnn-local-repo-ubuntu2004-8.9.3.28_1.0-1_amd64.deb
