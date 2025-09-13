set -o xtrace

# works for 11.8 and higher installed using deb file

# To uninstall previous CUDA versions
# nvidia-* and libnvidia-* removes drivers also. Better to remove everything and reinstall.
# libcudnn8* removed cuDNN
sudo apt-get -y --purge remove cuda-* nvidia-* gds-tools-* libcublas-* libcufft-* libcufile-* libcurand-* libcusolver-* libcusparse-* libnpp-* libnvidia-* libnvjitlink-* libnvjpeg-* nsight* nvidia-* libnvidia-* libcudnn8*

# For older version also run below
sudo apt-get -y --purge remove "*cublas*" "*cufft*" "*curand*" "*cusolver*" "*cusparse*" "*npp*" "*nvjpeg*" "cuda*" "nsight*"

# cleanup uninstall
sudo apt-get -y autoremove
sudo apt-get -y autoclean

# remove cuda directories
sudo rm -rf /usr/local/cuda*

# below causes error:
# The repository 'file:/var/XYZ  Release' no longer has a Release file.
sudo rm -rf /etc/apt/sources.list.d/cuda*
sudo rm -rf /etc/apt/sources.list.d/cudnn*
sudo rm -rf /etc/apt/sources.list.d/nccl-*

sudo rm -rf /var/cudnn-local-repo*
sudo rm -rf /var/cuda-repo*
sudo rm -rf /var/nccl-repo*

sudo dpkg -r cuda
sudo dpkg -r $(dpkg -l | grep '^ii  cudnn' | awk '{print $2}')

# https://developer.nvidia.com/blog/updating-the-cuda-linux-gpg-repository-key/
sudo apt-key del 7fa2af80

sudo apt -y update