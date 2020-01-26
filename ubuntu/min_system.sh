#!/bin/bash
#fail if any errors
set -e
set -o xtrace

sudo apt-get -y update
sudo apt-get -y install git curl wget xclip xz-utils tar apt-transport-https trash-cli bash-completion fslint fdupes
sudo apt-get -y install tlp powertop tlp-rdw inxi procinfo nvidia-prime htop #conky-all #conky-cli