#!/bin/bash
#fail if any errors
set -eu -o pipefail -o xtrace # fail if any command failes, log all commands, -o xtrace

if [[ -n "$WSL_DISTRO_NAME" ]]; then
    read -p "Make sure to follow manual steps in wsl_prep.sh. Proceed? (y/N): " response && [[ $response =~ ^[Yy]$ ]] || { echo "Exiting."; exit 1; }

    # share .ssh keys
    mkdir -p ~/.ssh
    cp -r /mnt/c/Users/$USER/.ssh ~/.ssh
    bash ssh_perms.sh

    # make sure we don't check-in with CRLFs
    git config --global core.autocrlf input
    # setup git credentials sharing
    cmd.exe /c "git config --global credential.helper wincred"
    git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
else
    # Check if nvcc is installed
    if ! command -v /usr/local/cuda/bin/nvcc &> /dev/null && ! command -v nvcc &> /dev/null; then
        read -p "CUDA not found. Do you want to install CUDA 12.4? (y/N): " install_cuda
        if [[ $install_cuda =~ ^[Yy]$ ]]; then
            bash install_cuda12.4.sh
        else
            echo "Skipping CUDA installation."
        fi
    fi
fi

# This installs anaconda and other libs on top of install_sandbox.sh

# this commands are same as in Dockerfile

# install core packages
bash cp_dotfiles.sh
bash min_system.sh
bash gitconfig.sh
bash install_fzf.sh


bash install_miniconda.sh


# Source the conda.sh script directly so we don't have reopen the terminal
. $HOME/miniconda3/etc/profile.d/conda.sh

conda activate base

# install Poetry
curl -sSL https://install.python-poetry.org | python3 -
pip install --upgrade nvitop

bash install_dl_frameworks.sh

