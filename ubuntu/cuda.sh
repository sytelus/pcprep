#!/bin/bash
#fail if any errors
set -e
set -o xtrace

if [ -d "/usr/local/cuda-10.0" ]; then
    echo *********** cuda 10.0 already detected so not installed
    exit 0
fi

# ----------------------------- CUDA 10.0 -----------------------
# #CUDA 10.0
wget -P ~/Downloads/ https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_410.48_linux
sudo sh ~/Downloads/cuda_10.0.130_410.48_linux

FILE=~/.bashrc
LINE='export PATH=/usr/local/cuda-10.0/bin:/usr/local/cuda-10.0/NsightCompute-1.0${PATH:+:${PATH}}'
grep -q "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
LINE='export LD_LIBRARY_PATH=/usr/local/cuda-10.0/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}'
grep -q "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

# #cuDNN 
echo ----------------------------------------------------
echo Open browser and download cuDNN from following link. Kep file in ~/Downloads.
echo https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.4.38/Production/10.0_20190923/Ubuntu18_04-x64/libcudnn7_7.6.4.38-1%2Bcuda10.0_amd64.deb
read -p "Press enter when done"
# wget -P ~/Downloads/ https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.4.38/Production/10.0_20190923/Ubuntu18_04-x64/libcudnn7_7.6.4.38-1%2Bcuda10.0_amd64.deb
sudo dpkg -i ~/Downloads/libcudnn7_7.6.4.38-1+cuda10.0_amd64.deb
# ---------------------------------------------------------------


# echo "login to https://developer.nvidia.com/cuda-10.0-download-archive?target_os=Linux&target_arch=x86_64&target_distro=Ubuntu&target_version=1804&target_type=debnetwork"
# echo "download and put in ~/Downloads/ -> https://developer.nvidia.com/compute/machine-learning/cudnn/secure/v7.4.2/prod/10.0_20181213/cudnn-10.0-linux-x64-v7.4.2.24.tgz"
# read -p "Press enter to continue"

# ----------------------------- CUDA 10.1 -----------------------
# tar -xzvf ~/Downloads/cudnn-10.1-linux-x64-v7.6.4.38.tgz -C ~/Downloads/
# sudo cp ~/Downloads/cuda/include/cudnn.h /usr/local/cuda/include
# sudo cp ~/Downloads/cuda/lib64/libcudnn* /usr/local/cuda/lib64
# sudo chmod a+r /usr/local/cuda/include/cudnn.h /usr/local/cuda/lib64/libcudnn*



# ----------------------------- CUDA 10.1 -----------------------
# #CUDA 10.1
# wget -P ~/Downloads/ http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_418.87.00_linux.run
# sudo sh ~/Downloads/cuda_10.1.243_418.87.00_linux.run
# echo 'export PATH=/usr/local/cuda-10.1/bin:/usr/local/cuda-10.1/NsightCompute-2019.1${PATH:+:${PATH}}' >> ~/.bashrc
# echo 'export LD_LIBRARY_PATH=/usr/local/cuda-10.1/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> ~/.bashrc

# cuDNN 7.6
# login https://developer.nvidia.com/rdp/cudnn-download
# wget -P ~/Downloads/ https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.4.38/Production/10.1_20190923/Ubuntu18_04-x64/libcudnn7_7.6.4.38-1%2Bcuda10.1_amd64.deb
# sudo dpkg -i ~/Downloads/libcudnn7_7.6.4.38-1+cuda10.1_amd64.deb
# --------------------------------------------------------------------------------------


# ----------------------------- CUDA 10.1 - doesn't work with TF -----------------------
# #CUDA 10.1
# wget -P ~/Downloads/ http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_418.87.00_linux.run
# sudo sh ~/Downloads/cuda_10.1.243_418.87.00_linux.run

# cuDNN 7.6
# login https://developer.nvidia.com/rdp/cudnn-download
# wget -P ~/Downloads/ https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.4.38/Production/10.1_20190923/Ubuntu18_04-x64/libcudnn7_7.6.4.38-1%2Bcuda10.1_amd64.deb
# sudo dpkg -i ~/Downloads/libcudnn7_7.6.4.38-1+cuda10.1_amd64.deb
# --------------------------------------------------------------------------------------
