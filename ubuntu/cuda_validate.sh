echo Please execute commands to install CUDA manually
exit 0

#!/bin/bash
#fail if any errors
set -e
set -o xtrace

if [ -d "/usr/local/cuda-$cuda_major.$cuda_minor" ]; then
    echo *********** cuda $cuda_major.$cuda_minor already detected so not installed
    exit 0
fi

# TO Remove existing CUDA
#sudo apt-get --purge remove "*cublas*" "cuda*" "nsight*"
#sudo rm -rf /usr/local/cuda*


# ubuntu2004
distro=$(. /etc/os-release;echo $ID$VERSION_ID | tr -d '.')
arch='x86_64'
cuda_major='11'
cuda_minor='8'
cuda_patch='0'

sudo apt-key del 7fa2af80

# do not use network setup, use local setup for specific cuda version
wget https://developer.download.nvidia.com/compute/cuda/repos/$distro/$arch/cuda-$distro.pin
sudo mv cuda-$distro.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/$cuda_major.$cuda_minor.$cuda_patch/local_installers/cuda-repo-$distro-$cuda_major-$cuda_minor-local_$cuda_major.$cuda_minor.$cuda_patch-520.61.05-1_amd64.deb
sudo dpkg -i cuda-repo-$distro-$cuda_major-$cuda_minor-local_$cuda_major.$cuda_minor.$cuda_patch-520.61.05-1_amd64.deb
sudo cp /var/cuda-repo-$distro-$cuda_major-$cuda_minor-local/cuda-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get -y install cuda
# must be separate
sudo apt-get -y install nvidia-gds

#sudo reboot

Add below in .bashrc (it installs 12.0 even if we say 11.8)
export PATH=/usr/local/cuda-12.0/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda-12.0/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
source ~/.bashrc

# NCCL installation
# see https://docs.nvidia.com/deeplearning/nccl/install-guide/index.html
download from https://developer.nvidia.com/downloads/remure2165ubuntu20048664nccl-local-repo-ubuntu2004-2165-cuda11810-1amd64deb
sudo apt install libnccl2=2.16.5-1+cuda11.8 libnccl-dev=2.16.5-1+cuda11.8

# cuDNN install
download from https://developer.nvidia.com/downloads/c118-cudnn-local-repo-ubuntu2004-8708410-1amd64deb
sudo dpkg -i cudnn-local-repo-ubuntu2004-8.7.0.84_1.0-1_amd64.deb
sudo cp /var/cudnn-local-repo-*/cudnn-local-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get install libcudnn8=8.7.0.84-1+cuda$cuda_major.$cuda_minor
sudo apt-get install libcudnn8-dev=8.7.0.84-1+cuda$cuda_major.$cuda_minor
sudo apt-get install libcudnn8-samples=8.7.0.84-1+cuda$cuda_major.$cuda_minor

# validation
# driver version
cat /proc/driver/nvidia/version

# cuda validation
cd ~/GitHubSrc
git clone https://github.com/nvidia/cuda-samples
cd cuda-samples/Samples/1_Utilities/deviceQuery
make
./deviceQuery

# cuDNN validation (doesn't work due to FreeImage.h)
cp -r /usr/src/cudnn_samples_v8/ $HOME
cd  $HOME/cudnn_samples_v8/mnistCUDNN
make clean && make
./mnistCUDNN