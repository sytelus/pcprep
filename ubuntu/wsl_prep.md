# Steps to prepare WSL environment

To start from  scratch:

1. Go to Apps > Installed Apps > Ubuntu > Uninstall.
2. Reinstall and update wsl and install distro:
```bash
# in admin prompt
wsl --uninstall
wsl --update
# wsl --install -d Ubuntu-22.04
wsl --install -d Ubuntu-24.04
# init distro, enter user name, password and complete the setup
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

## Map folders

Assuming you store your GitHub repos in `D:\GitHubSrc`, you can map it to WSL home directory so they are accessible from WSL at `~/GitHubSrc`:

```bash
wsl # start wsl
cd ~ # go to home
ln -s "/mnt/d/GitHubSrc" "$HOME/GitHubSrc" # create symlink
```

## Install stuff

```bash
# in wsl
cd ~/GitHubSrc/pcprep/ubuntu
bash prepare_new_box.sh
```
