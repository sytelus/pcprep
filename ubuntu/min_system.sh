#!/bin/bash
#fail if any errors
set -e
set -o xtrace

sudo apt-get -y update
sudo apt-get -y install git curl wget xclip xz-utils tar apt-transport-https trash-cli bash-completion
sudo apt-get -y install tlp powertop tlp-rdw inxi procinfo nvidia-prime htop #conky-all #conky-cli
sudo apt-get -y install build-essential cmake libopencv-dev g++ libopenmpi-dev zlib1g-dev
# needed for docker
sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release
