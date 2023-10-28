# CUDA 12.0
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.0-1_all.deb
sudo dpkg -i cuda-keyring_1.0-1_all.deb
sudo apt-get update
sudo apt-get -y install cuda
rm cuda-keyring_1.0-1_all.deb

# cuDNN install
wget https://developer.download.nvidia.com/compute/redist/cudnn/v8.8.0/local_installers/12.0/cudnn-local-repo-ubuntu2004-8.8.0.121_1.0-1_amd64.deb
sudo dpkg -i cudnn-local-repo-ubuntu2004-8.8.0.121_1.0-1_amd64.deb
sudo cp /var/cudnn-local-repo-*/cudnn-local-*-keyring.gpg /usr/share/keyrings/
sudo apt-get -y update
sudo apt-get install libcudnn8=8.8.0.121-1+cuda12.0
sudo apt-get install libcudnn8-dev=8.8.0.121-1+cuda12.0
sudo apt-get install libcudnn8-samples=8.8.0.121-1+cuda12.0
rm cudnn-local-repo-ubuntu2004-8.8.0.121_1.0-1_amd64.deb