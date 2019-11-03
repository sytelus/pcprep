#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# install VS code, dropbox, chrome: https://code.visualstudio.com/, anaconda.sh

sudo apt-get -y update
sudo apt-get -y install git curl

#conda install python=3.6

sudo apt-get -y install git curl wget xclip
git config --global diff.tool vscode
git config --global difftool.vscode.cmd "code --wait --diff $LOCAL $REMOTE"
git config --global core.editor "code --wait"

sudo apt-get -y install bash-completion gnome-tweak-tool gnome-shell-extensions gnome-tweaks
sudo apt-get -y install numix-gtk-theme materia-gtk-theme gtk2-engines-murrine gtk2-engines-pixbuf gnome-themes-standard
sudo apt-get -y install tlp powertop tlp-rdw inxi nvidia-prime
sudo apt-get -y install gnome-calculator #will get you GTK
sudo apt-get -y install libgl1-mesa-glx libegl1-mesa libxrandr2 libxrandr2 libxss1 libxcursor1 libxcomposite1 libasound2 libxi6 liblcms2-dev libxtst6
sudo apt-get -y install swig cmake libopenmpi-dev python3-dev zlib1g-dev


# curl -O https://repo.anaconda.com/archive/Anaconda3-2019.07-Linux-x86_64.sh
# bash Anaconda3-2019.07-Linux-x86_64.sh
# conda install python=3.6

sudo apt-get -y install libopencv-dev
sudo apt-get -y install build-essential
sudo apt-get -y install cmake git libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev
sudo apt-get -y install python-dev python-numpy libtbb2 libtbb-dev libjpeg-dev libpng-dev libtiff-dev libdc1394-22-dev

#packages
sudo apt-get -y install g++ gcc-arm-linux-gnueabi g++-arm-linux-gnueabi
sudo apt-get -y install python-wstool
sudo apt-get -y install vlc browser-plugin-vlc
sudo apt-get -y install p7zip-full p7zip-rar

sudo apt-get -y update

sudo apt-get -y install python-opengl

sudo apt-get -y install terminator
sudo apt-get -y install dconf-tools
sudo apt-get -y install gcc-arm-linux-gnueabi g++-arm-linux-gnueabi
sudo apt-get -y install libusb-1.0-0-dev
sudo apt-get -y install g++
sudo apt-get -y install gconf-editor

sudo adduser $USER dialout

sudo update-alternatives --set editor /usr/bin/code
