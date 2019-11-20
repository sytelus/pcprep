#!/bin/bash
#fail if any errors
set -e
set -o xtrace

wget -P ~/Downloads/ https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
sudo dpkg -i ~/Downloads/packages-microsoft-prod.deb
sudo add-apt-repository universe
sudo apt-get update
sudo apt-get install -y apt-transport-https
sudo apt-get update
sudo apt-get install -y dotnet-sdk-3.0