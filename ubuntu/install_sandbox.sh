#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# Run this on new VMs to instantly have dev environment


# copy dot files, rundocker command
bash cp_dotfiles.sh

# install blobfuse so you can map Azure blob storage
sudo apt-get install blobfuse2

# below two is only needed if docker is not already installed
#bash min_system.sh
#bash docker_install.sh

# installs NVidia docker runtime
# check:
#   dpkg-query --show --showformat='${db:Status-Status}\n' nvidia-docker2
# if not installed then run below
# bash nv_container_tk.sh

mkdir -p ~/data # docker will mount this folder as ~/dataroot

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
