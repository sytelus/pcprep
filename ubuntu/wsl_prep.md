# Steps to prepare a WSL environment

To start from scratch:

1. Back up anything needed from an existing distribution. `wsl --unregister`
   permanently deletes that distribution's filesystem; use it only when you
   really intend to replace the named distribution.
2. From an Administrator PowerShell or Command Prompt, update WSL and install
   Ubuntu 26.04 under the local name `u2`:

```powershell
# Optional destructive reset of this one distribution:
# wsl --unregister u2
wsl --update
wsl --install -d Ubuntu-26.04 --name u2
# Initialize the distro, enter a user name and password, and complete setup.
wsl -s u2
wsl -d u2
```

3. (Optional) Move WSL vhd file

```powershell
# Exit WSL first. The VHDX can grow large, so another drive may be preferable.
mkdir e:\wsl_vhd
wsl --shutdown
wsl --manage u2 --move e:\wsl_vhd
wsl -l -v
```



## Install stuff

```bash
# Run these as the regular WSL user, not with sudo.
mkdir ~/GitHubSrc
cd ~/GitHubSrc
git clone https://github.com/sytelus/pcprep
cd pcprep/ubuntu
bash prepare_new_box.sh
```
