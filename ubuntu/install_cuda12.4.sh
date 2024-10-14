#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# from: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/
# # check if GPU is available
# lspci | grep -i nvidia
# # check Linux version
# uname -m && cat /etc/*release



# from https://developer.nvidia.com/cuda-12-4-0-download-archive?target_os=Linux&target_arch=x86_64&Distribution=Ubuntu&target_version=22.04&target_type=deb_local
# install CUDA 12.4 for Ubuntu 22.04

if [[ -n "$WSL_DISTRO_NAME" ]]; then
    # https://developer.nvidia.com/cuda-12-4-0-download-archive?target_os=Linux&target_arch=x86_64&Distribution=WSL-Ubuntu&target_version=2.0&target_type=deb_local
    wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin
    sudo mv cuda-wsl-ubuntu.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.4.0/local_installers/cuda-repo-wsl-ubuntu-12-4-local_12.4.0-1_amd64.deb
    sudo dpkg -i cuda-repo-wsl-ubuntu-12-4-local_12.4.0-1_amd64.deb
    sudo cp /var/cuda-repo-wsl-ubuntu-12-4-local/cuda-*-keyring.gpg /usr/share/keyrings/
    sudo apt-get -y update
    sudo apt-get -y install cuda-toolkit-12-4

    sudo apt-get -y update
    sudo apt-get -y install cuda-toolkit
else
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
    sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.4.0/local_installers/cuda-repo-ubuntu2204-12-4-local_12.4.0-550.54.14-1_amd64.deb
    sudo dpkg -i cuda-repo-ubuntu2204-12-4-local_12.4.0-550.54.14-1_amd64.deb
    sudo cp /var/cuda-repo-ubuntu2204-12-4-local/cuda-*-keyring.gpg /usr/share/keyrings/
    sudo apt-get -y update
    sudo apt-get -y install cuda-toolkit-12-4
    #rm cuda-repo-ubuntu2204-12-4-local_12.4.0-550.54.14-1_amd64.deb

    sudo apt-get -y update
    sudo apt-get -y install cuda-toolkit
    sudo apt-get -y install nvidia-gds
fi

# install cuDNN
wget https://developer.download.nvidia.com/compute/cudnn/9.5.0/local_installers/cudnn-local-repo-ubuntu2204-9.5.0_1.0-1_amd64.deb
sudo dpkg -i cudnn-local-repo-ubuntu2204-9.5.0_1.0-1_amd64.deb
sudo cp /var/cudnn-local-repo-ubuntu2204-9.5.0/cudnn-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get -y install cudnn-cuda-12

echo "Must reboot the machine!"