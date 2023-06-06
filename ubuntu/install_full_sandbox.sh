# This installs anaconda and other libs on top of install_sandbox.sh

# this commands are same as in Dockerfile

# install core packages
sudo apt-get install --assume-yes --no-install-recommends \
      git curl wget xclip xz-utils tar apt-transport-https trash-cli bash-completion \
      tlp powertop tlp-rdw inxi procinfo nvidia-prime htop #conky-all #conky-cli \
      build-essential cmake libopencv-dev g++ libopenmpi-dev zlib1g-dev \
      fortune-mod sl espeak figlet sysvbanner cowsay oneko cmatrix toilet pi xcowsay aview bb rig weather-util ponysay \
      fslint fdupes locate \
      apt-transport-https ca-certificates curl gnupg lsb-release \
      bzip2 libglib2.0-0 libxext6 libsm6 libxrender1 mercurial subversion \
      nvtop virt-what sudo zlib1g g++ freeglut3-dev build-essential libx11-dev \
      libxmu-dev libxi-dev libglu1-mesa libglu1-mesa-dev libfreeimage3 libfreeimage-dev

sudo apt-get clean

wget https://repo.anaconda.com/archive/Anaconda3-2022.10-Linux-x86_64.sh -O ~/anaconda.sh
sudo /bin/bash ~/anaconda.sh -b -p /opt/conda
rm ~/anaconda.sh
sudo ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh
sudo chown -R $USER /opt/cond
sudo chown -R $USER ~/.conda

conda init bash
conda activate base

conda install -y pytorch torchvision torchaudio pytorch-cuda=11.8 -c pytorch-nightly -c nvidia
conda install -y -c conda-forge tensorflow
conda install -y -c conda-forge tensorboard keras gpustat scikit-learn-intelex py3nvml glances

