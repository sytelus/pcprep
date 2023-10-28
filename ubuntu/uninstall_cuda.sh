# works for 11.8 and higher installed using deb file

# To uninstall previous CUDA versions
# nvidia-* and libnvidia-* removes drivers also. Better to remove everything and reinstall.
# libcudnn8* removed cuDNN
sudo apt-get --purge remove cuda-* nvidia-* gds-tools-* libcublas-* libcufft-* libcufile-* libcurand-* libcusolver-* libcusparse-* libnpp-* libnvidia-* libnvjitlink-* libnvjpeg-* nsight* nvidia-* libnvidia-* libcudnn8*

# For older version also run below
sudo apt-get --purge remove "*cublas*" "*cufft*" "*curand*" "*cusolver*" "*cusparse*" "*npp*" "*nvjpeg*" "cuda*" "nsight*"

# cleanup uninstall
sudo apt-get autoremove
sudo apt-get autoclean

# remove cuda directories
sudo rm -rf /usr/local/cuda*

sudo dpkg -r cuda
sudo dpkg -r $(dpkg -l | grep '^ii  cudnn' | awk '{print $2}')