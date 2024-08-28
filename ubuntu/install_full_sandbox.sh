#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# This installs anaconda and other libs on top of install_sandbox.sh

# this commands are same as in Dockerfile

# install core packages
bash cp_dotfiles.sh
bash min_system.sh
bash gitconfig.sh
bash install_fzf.sh


# install mini conda with Python 3.11 (3.12 has breaking changes with imp module)
mkdir -p ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-py311_24.5.0-0-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
rm -rf ~/miniconda3/miniconda.sh

# modify .bashrc
~/miniconda3/bin/conda init bash

# update to latest version
# conda update -n base -c defaults conda

# Source the conda.sh script directly so we don't have reopen the terminal
. $HOME/miniconda3/etc/profile.d/conda.sh

conda activate base

# install Poetry
curl -sSL https://install.python-poetry.org | python3 -

bash install_dl_frameworks.sh

if [[ -n "$WSL_DISTRO_NAME" ]]; then
    # share .ssh keys
    mkdir -p ~/.ssh
    cp -r /mnt/c/Users/$USER/.ssh ~/.ssh
    bash ssh_perms.sh

    # make sure we don't check-in with CRLFs
    git config --global core.autocrlf input
    # setup git credentials sharing
    cmd.exe /c "git config --global credential.helper wincred"
    git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager-core.exe"
fi
