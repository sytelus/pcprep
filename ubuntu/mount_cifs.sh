#!/bin/bash
#fail if any errors
set -e
set -o xtrace

sudo apt-get update
sudo apt-get install -y cifs-utils

# Arguments:
# $1 - name of mount i.e. /mnt/$1
# $2 - share location
# $3 - user name
# $4 - password

sudo mkdir -p /mnt/$1
if [ ! -d "/etc/smbcredentials" ]; then
sudo mkdir -p /etc/smbcredentials
fi
if [ ! -f "/etc/smbcredentials/$1.cred" ]; then
    sudo bash -c 'echo "username=$3" >> /etc/smbcredentials/$1.cred'
    sudo bash -c 'echo "password=$4" >> /etc/smbcredentials/$1.cred'
fi
sudo chmod 600 /etc/smbcredentials/$1.cred
sudo bash -c 'echo "$2 /mnt/$1 cifs nofail,vers=3.0,credentials=/etc/smbcredentials/$1.cred,dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab'
sudo mount -t cifs $2 /mnt/$1 -o vers=3.0,credentials=/etc/smbcredentials/$1.cred,dir_mode=0777,file_mode=0777,serverino