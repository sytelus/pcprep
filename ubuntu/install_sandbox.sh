#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# Run this on new VMs to instantly have dev environment


# copy dot files, rundocker command
bash cp_dotfiles.sh

# install blobfuse so you can map Azure blob storage
# see instructions at https://learn.microsoft.com/en-us/azure/storage/blobs/blobfuse2-how-to-deploy#how-to-install-blobfuse2
distribution=$(. /etc/os-release;echo $ID/$VERSION_ID)
wget https://packages.microsoft.com/config/$distribution/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install libfuse3-dev fuse3
sudo apt-get install blobfuse2

# below two is only needed if docker is not already installed
#bash min_system.sh
#bash docker_install.sh

# installs NVidia docker runtime
# check:
#   dpkg-query --show --showformat='${db:Status-Status}\n' nvidia-docker2
# if not installed then run below
# bash nv_container_tk.sh

# pull docker that we will use
sudo docker pull sytelus/dev
# test the docker by printing out GPUs
sudo docker run --rm --gpus all sytelus/dev nvidia-smi

# create root folder for data. This will be mapped in rundocker.sh
sudo mkdir -p /dataroot

echo
echo
echo "###################################################################"
echo "Use:"
echo "bash rundocker.sh"
echo "###################################################################"
