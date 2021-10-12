#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# install VS code, dropbox, chrome: https://code.visualstudio.com/, anaconda.sh

# for WSL get GitHubSrc from host
#ln -s /mnt/d/GitHubSrc/ GitHubSrc

bash cp_dotfiles.sh
#bash gsettings.sh

bash min_system.sh
#bash gitconfig.sh

# anaconda install hangs on machines with lots of CPUs
# bash anaconda.sh
# bash ml.sh

bash docker_install.sh

bash nv_container_tk.sh

# pull docker that we will use
sudo docker pull sytelus/archai
# test the docker by printing out GPUs
sudo docker run --rm --gpus all sytelus/archai nvidia-smi

# create root folder for data. This will be mapped in rundocker.sh
sudo mkdir -p /dataroot

echo
echo
echo "###################################################################"
echo "Use:"
echo "bash rundocker.sh"
echo "###################################################################"
