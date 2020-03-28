#!/bin/bash
#fail if any errors
set -e
set -o xtrace

if [ -d "/usr/local/cuda-10.1" ]; then
    echo *********** cuda 10.1 already detected so not installed
    exit 0
fi

# # ----------------------------- CUDA 10.0 -----------------------
# # #CUDA 10.0
# wget -P ~/Downloads/ https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_410.48_linux
# sudo sh ~/Downloads/cuda_10.0.130_410.48_linux

# FILE=~/.bashrc

# LINE='export PATH=/usr/local/cuda-10.0/bin:/usr/local/cuda-10.0/NsightCompute-1.0${PATH:+:${PATH}}'
# grep -q "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
# LINE='export LD_LIBRARY_PATH=/usr/local/cuda-10.0/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}'
# grep -q "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

# # #cuDNN
# echo ----------------------------------------------------
# echo Open browser and download cuDNN from following link. Kep file in ~/Downloads.
# echo https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.4.38/Production/10.0_20190923/Ubuntu18_04-x64/libcudnn7_7.6.4.38-1%2Bcuda10.0_amd64.deb
# read -p "Press enter when done"
# # wget -P ~/Downloads/ https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.4.38/Production/10.0_20190923/Ubuntu18_04-x64/libcudnn7_7.6.4.38-1%2Bcuda10.0_amd64.deb
# sudo dpkg -i ~/Downloads/libcudnn7_7.6.4.38-1+cuda10.0_amd64.deb
# # ---------------------------------------------------------------


echo "login to https://developer.nvidia.com/"
read -p "Press enter to continue"


# remove existing CUDA:
# sudo /usr/local/cuda/bin/cuda-uninstaller


################# Option 1
wget http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_418.87.00_linux.run
sudo sh cuda_10.1.243_418.87.00_linux.run

wget -P ~/Downloads/ https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/10.1_20191031/Ubuntu18_04-x64/libcudnn7_7.6.5.32-1%2Bcuda10.1_amd64.deb
sudo dpkg -i ~/Downloads/libcudnn7_7.6.5.32-1+cuda10.1_amd64.deb

################# Option 2 (from tensorflow website)
# Add NVIDIA package repositories
# wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-repo-ubuntu1804_10.1.243-1_amd64.deb
# sudo dpkg -i cuda-repo-ubuntu1804_10.1.243-1_amd64.deb
# sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
# sudo apt-get update
# wget http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64/nvidia-machine-learning-repo-ubuntu1804_1.0.0-1_amd64.deb
# sudo apt install ./nvidia-machine-learning-repo-ubuntu1804_1.0.0-1_amd64.deb
# sudo apt-get update

# # Install NVIDIA driver
# #sudo apt-get install --no-install-recommends nvidia-driver-418
# # Reboot. Check that GPUs are visible using the command: nvidia-smi

# # Install development and runtime libraries (~4GB)
# sudo apt-get install --no-install-recommends \
#     cuda-10-1 \
#     libcudnn7=7.6.4.38-1+cuda10.1  \
#     libcudnn7-dev=7.6.4.38-1+cuda10.1


# Install TensorRT. Requires that libcudnn7 is installed above.
sudo apt-get install -y --no-install-recommends libnvinfer6=6.0.1-1+cuda10.1 \
    libnvinfer-dev=6.0.1-1+cuda10.1 \
    libnvinfer-plugin6=6.0.1-1+cuda10.1
