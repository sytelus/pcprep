# Steps to prepare WSL environment

# First move WSL vhd file to drive where you have space!

# Steps:
# From: https://superuser.com/a/1804204/121618
# Stop the distribution you want to relocate: wsl --terminate Ubuntu or wsl --shutdown.
# Create a backup, just to be sure: wsl --export Ubuntu D:\Ubuntu-backup.tar`.
# Start the Registry Editor (regedit.exe - it requires elevated permissions).
# Navigate to Computer\HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\. Here, you can find all the existing distributions. Find the one that you want to relocate based on the DistributionName entry (in my case, it is Ubuntu).
# The BasePath entry shows the current location of the disk. In my case: C:\Users\myuser\AppData\Local\Packages\CanonicalGroupLimited.UbuntuonWindows_79rhkp1fndgsc\LocalState. If you open this folder, you will see that it has one ext4.vhdx file. This is the disk file.
# Copy this file to the location where you want to have it. For example, cp C:\Users\myuser\AppData\Local\Packages\CanonicalGroupLimited.UbuntuonWindows_79rhkp1fndgsc\LocalState\ext4.vhdx D:\wsl\Ubuntu\.
# Change the BashPath entry in Registry Editor to point to this new location.
# Just start the WSL distribution, it will use the disk in the new location. At this point, you can delete the disk file from the original location.

# Next, map local GitHubSrc to WSL home directory

# simlink GitHubSrc
# ln -s "/mnt/d/GitHubSrc" "$HOME/GitHubSrc"

# Next, gotopcprep repo and run install_full_sandbox.sh in ubuntu folder