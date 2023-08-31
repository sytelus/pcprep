# CUDA 12.0

# solve: E: Conflicting values set for option Signed-By regarding source https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/ /: /usr/share/keyrings/cuda-archive-keyring.gpg !=
sudo mv /etc/apt/sources.list.d/cuda-ubuntu2004-x86_64.list /etc/apt/sources.list.d/cuda-ubuntu2004-x86_64.list.old

wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.1-1_all.deb
# ************** Do not delete any key even if message says so *********
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
# use aptitude instead of apt-get because of dependency issues
sudo aptitude install cuda
rm cuda-keyring_1.0-1_all.deb

# cuDNN install
sudo apt-get install -y zlib1g
wget https://developer.nvidia.com/downloads/compute/cudnn/secure/8.9.4/local_installers/12.x/cudnn-local-repo-ubuntu2004-8.9.4.25_1.0-1_amd64.deb/
sudo dpkg -i cudnn-local-repo-ubuntu2004-8.9.4.25_1.0-1_amd64.deb
sudo cp /var/cudnn-local-repo-*/cudnn-local-*-keyring.gpg /usr/share/keyrings/
sudo apt-get -y update
sudo apt-get install libcudnn8=8.9.4.25-1+cuda12.2
sudo apt-get install libcudnn8-dev=8.9.4.25-1+cuda12.2
sudo apt-get install libcudnn8-samples=8.9.4.25-1+cuda12.2
rm cudnn-local-repo-ubuntu2004-8.9.4.25_1.0-1_amd64.deb