#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# install core packages
sudo apt-get install --assume-yes --no-install-recommends \
      git curl wget xclip xz-utils tar apt-transport-https trash-cli bash-completion \
      tlp powertop tlp-rdw inxi procinfo nvidia-prime htop \
      build-essential cmake libopencv-dev g++ libopenmpi-dev zlib1g-dev \
      fortune-mod sl espeak figlet sysvbanner cowsay oneko cmatrix toilet pi xcowsay aview bb rig weather-util \
      fdupes locate keychain pass \
      apt-transport-https ca-certificates curl gnupg lsb-release gpustat \
      bzip2 libglib2.0-0 libxext6 libsm6 libxrender1 mercurial subversion \
      nvtop virt-what sudo zlib1g g++ freeglut3-dev build-essential libx11-dev \
      libxmu-dev libxi-dev libglu1-mesa libglu1-mesa-dev libfreeimage3 libfreeimage-dev

# update stdc, without this pytest discovery fails
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt-get -y update
sudo apt-get install -y gcc-4.9
sudo apt-get install -y --only-upgrade libstdc++6