#!/bin/bash
#fail if any errors
set -e
set -o xtrace

sudo apt update
sudo apt-get install -y git
sudo apt-get install -y build-essential

cd ~/GitHubSrc
git clone git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git
cd linux-firmware
sudo cp iwlwifi-* /lib/firmware/
cd ..

git clone https://git.kernel.org/pub/scm/linux/kernel/git/iwlwifi/backport-iwlwifi.git
cd backport-iwlwifi
sudo make defconfig-iwlwifi-public
sudo make -j4
sudo make install
 
#update-initramfs -u

# Warning: modules_install: missing 'System.map' file. Skipping depmod.
# depmod will prefer updates/ over kernel/ -- OK!
# Note:
# You may or may not need to update your initramfs, you should if
# any of the modules installed are part of your initramfs. To add
# support for your distribution to do this automatically send a
# patch against "update-initramfs.sh". If your distribution does not
# require this send a patch with the '/usr/bin/lsb_release -i -s'
# ("Ubuntu") tag for your distribution to avoid this warning.

# Your backported driver modules should be installed now.
# Reboot.

# ln: failed to create hard link '/boot/initrd.img-5.0.0-31-generic.dpkg-bak' => '/boot/initrd.img-5.0.0-31-generic': Operation not permitted
# cp: cannot create regular file '/boot/initrd.img-5.0.0-31-generic.dpkg-bak': Permission denied
