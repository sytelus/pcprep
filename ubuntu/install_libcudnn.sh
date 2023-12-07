set -o xtrace

# libcudnn8 cannot be install without below

# https://developer.nvidia.com/blog/updating-the-cuda-linux-gpg-repository-key/
sudo apt-key del 7fa2af80
wget -P ~/ https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.0-1_all.deb
sudo dpkg -i ~/cuda-keyring_1.0-1_all.deb
sudo apt-get -y update
#sudo apt-get -y install libcudnn8=8.9.5.30_1+cuda12.1