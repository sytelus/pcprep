# CUDA 12.2
# wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.1-1_all.deb
# # ************** Do not delete any key even if message says so *********
# sudo dpkg -i cuda-keyring_1.1-1_all.deb
# sudo apt-get update
# # use aptitude instead of apt-get because of dependency issues
# sudo aptitude install cuda
# rm cuda-keyring_1.0-1_all.deb

# To uninstall previous versions use uninstall_cuda.sh
# To solve error: E: Conflicting values set for option Signed-By regarding source https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/ /: /usr/share/keyrings/cuda-archive-keyring.gpg !=
# sudo mv /etc/apt/sources.list.d/cuda-ubuntu2004-x86_64.list /etc/apt/sources.list.d/cuda-ubuntu2004-x86_64.list.old
# CUDA 11.8
# DO NOT INSTALL nighly PyTorch
# Current PyTorch stable version do not support > CUDA 11.8
# CUDA 11.8 must be installed using local deb for ease of later removal.
# DO NOT use network deb as it installs 12.2 which is not supported by PyTorch
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda-repo-ubuntu2004-11-8-local_11.8.0-520.61.05-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2004-11-8-local_11.8.0-520.61.05-1_amd64.deb
sudo cp /var/cuda-repo-ubuntu2004-11-8-local/cuda-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get -y install cuda

# cuDNN install
sudo apt-get install -y zlib1g
wget https://developer.nvidia.com/downloads/compute/cudnn/secure/8.9.5/local_installers/11.x/cudnn-local-repo-ubuntu2004-8.9.5.29_1.0-1_amd64.deb/
sudo dpkg -i cudnn-local-repo-ubuntu2004-8.9.5.29_1.0-1_amd64.deb
sudo cp /var/cudnn-local-repo-*/cudnn-local-*-keyring.gpg /usr/share/keyrings/
sudo apt-get -y update
sudo apt-get install libcudnn8=8.9.5.29-1+cuda11.8
sudo apt-get install libcudnn8-dev=8.9.5.29-1+cuda11.8
sudo apt-get install libcudnn8-samples=8.9.5.29-1+cuda11.8
rm cudnn-local-repo-ubuntu2004-8.9.5.29_1.0-1_amd64.deb

#Above might still install 12.2. Use below to install 11.8
sudo apt-get install cuda-toolkit-11-8
export CUDA_HOME=/usr/local/cuda-11.8/ # goes in .bashrc


# Use local CUDA version instead of one in /usr/bin
# If below is not done then nvcc will be found in /usr/bin which is older
# Flash Attention won't install because it will detect wrong nvcc
# ************** Put this in .bashrc *********
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}