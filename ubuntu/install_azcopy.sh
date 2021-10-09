#!/bin/bash
#fail if any errors
set -e
set -o xtrace

which azcopy
mkdir -p ~/Downloads
cd ~/Downloads
wget https://aka.ms/downloadazcopy-v10-linux
tar -xvf downloadazcopy-v10-linux
cd azcopy_linux_amd64_10.7.0

sudo rm /usr/bin/azcopy
sudo cp azcopy /usr/bin/
sudo chmod +x /usr/bin/azcopy
which azcopy
azcopy