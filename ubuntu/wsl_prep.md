# Steps to prepare WSL environment

For group policy error/reinstall, try:

```bash
# in admin prompt
wsl --uninstall
wsl --update
wsl --install ubuntu
wsl --list # see available distributions
```

## Move WSL vhd file

Source: https://superuser.com/a/1804204/121618

1. Stop the distribution you want to relocate: `wsl --terminate` Ubuntu or `wsl --shutdown`.
2. Create a backup, just to be sure: wsl --export Ubuntu D:\Ubuntu-backup.tar`.
3. Start the Registry Editor (regedit.exe - it requires elevated permissions).
4. Navigate to `Computer\HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\`. Here, you can find all the existing distributions. Find the one that you want to relocate based on the DistributionName entry (in my case, it is Ubuntu).
5. The BasePath entry shows the current location of the disk. In my case: `C:\Users\myuser\AppData\Local\Packages\CanonicalGroupLimited.UbuntuonWindows_79rhkp1fndgsc\LocalState`. If you open this folder, you will see that it has one ext4.vhdx file. This is the disk file.
6. Copy this file to the location where you want to have it. For example, `cp C:\Users\myuser\AppData\Local\Packages\CanonicalGroupLimited.UbuntuonWindows_79rhkp1fndgsc\LocalState\ext4.vhdx D:\wsl\Ubuntu\`.
7. Change the BashPath entry in Registry Editor to point to this new location.
8. Just start the WSL distribution, it will use the disk in the new location. At this point, you can delete the disk file from the original location.

## Map folders

Map local GitHubSrc to WSL home directory

```bash
ln -s "/mnt/d/GitHubSrc" "$HOME/GitHubSrc"
```

## Install stuff

```bash
bash prepare_new_box.sh
```