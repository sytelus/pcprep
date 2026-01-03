# Steps to prepare WSL environment

To start from  scratch:

1. Go to Apps > Installed Apps > Ubuntu > Uninstall.
2. Reinstall and update wsl and install distro:
```bash
# in admin prompt
wsl --uninstall
wsl --update
# wsl --install -d Ubuntu-22.04
wsl --install -d Ubuntu-24.04 --name u2
# init distro, enter user name, password and complete the setup
wsl -s u2 # set u2 as default distro
wsl
```

3. (Optional) Move WSL vhd file

```bash
# exit from wsl, go back to command prompt
# make dir to vhd file which can big and you
# probably want to move it to a different drive
mkdir e:\wsl_vhd
wsl --shutdown
wsl --manage Ubuntu-22.04 --move e:\wsl_vhd
# list your distros to verify
wsl -l -v
```



## Install stuff

```bash
# in wsl
mkdir ~/GitHubSrc
cd ~/GitHubSrc
git clone https://github.com/sytelus/pcprep
cd pcprep/ubuntu
bash prepare_new_box.sh
```
