#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# install core packages
sudo apt-get install --assume-yes --no-install-recommends \
      git curl wget xclip xz-utils tar apt-transport-https trash-cli bash-completion \
      tlp powertop tlp-rdw inxi procinfo nvidia-prime htop aptitude \
      build-essential cmake libopencv-dev g++ libopenmpi-dev zlib1g-dev \
      fortune-mod sl espeak figlet sysvbanner cowsay oneko cmatrix toilet pi xcowsay aview bb rig weather-util \
      fdupes locate keychain pass micro zlib1g \
      apt-transport-https ca-certificates curl gnupg lsb-release  \
      bzip2 libglib2.0-0 libxext6 libsm6 libxrender1 mercurial subversion \
      virt-what sudo zlib1g g++ freeglut3-dev build-essential libx11-dev \
      libxmu-dev libxi-dev libglu1-mesa libglu1-mesa-dev libfreeimage3 \
      libfreeimage-dev vmtouch neofetch

# removed nvtop, gpustat

# update stdc, without this pytest discovery fails
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt-get -y update
#sudo apt-get install -y gcc-4.9
sudo apt-get install -y --only-upgrade libstdc++6

# install micro editor and make it default editor
sudo bash -c "cd /usr/bin; wget -O- https://getmic.ro | GETMICRO_REGISTER=y sh"

curl https://justine.lol/rusage/rusage.com >rusage
sudo chmod +x rusage
sudo mv rusage /usr/local/bin