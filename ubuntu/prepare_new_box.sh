#!/bin/bash
#fail if any errors
set -eu -o pipefail -o xtrace # fail if any command failes, log all commands, -o xtrace

export NO_NET=${NO_NET:-}
export user_name=${user_name:-}
export user_email=${user_email:-}
export INSTALL_PYTORCH=${INSTALL_PYTORCH:-1}
export WSL_DISTRO_NAME=${WSL_DISTRO_NAME:-}

# Check if NO_NET is not set and test internet connectivity
if [ -z "${NO_NET}" ]; then
    echo "Checking Internet connection..."
    export NO_NET=0
    if ! ping -w 5 -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo "No internet connectivity detected"
        export NO_NET=1
    fi
fi

if [[ -n "$WSL_DISTRO_NAME" ]]; then
    read -p "Make sure to follow manual steps in wsl_prep.sh. Proceed? (y/N): " response && [[ $response =~ ^[Yy]$ ]] || { echo "Exiting."; exit 1; }

    # share .ssh keys
    mkdir -p ~/.ssh
    if [ -d "/mnt/c/Users/$USER/.ssh" ]; then
        cp -r /mnt/c/Users/$USER/.ssh ~/.ssh
    fi
    bash ssh_perms.sh

    # provides browser integration with the host system
    sudo add-apt-repository -y ppa:wslutilities/wslu
    sudo apt update
    sudo apt install wslu -y

    # make sure we don't check-in with CRLFs
    git config --global core.autocrlf input
    # setup git credentials sharing
    cmd.exe /c "git config --global credential.helper wincred"
    if [[ "$(uname -m)" == "aarch64" ]]; then git config --global credential.helper "/mnt/c/Program\ Files/Git/clangarm64/bin/git-credential-manager.exe"; else git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"; fi
    git config --global credential.useHttpPath true

    # if using tailscale, create alias
    if [ -f "/mnt/c/Program Files/Tailscale/tailscale.exe" ]; then
        echo 'alias tailscale="/mnt/c/Program\ Files/Tailscale/tailscale.exe"' >> ~/.zshrc
        echo 'alias tailscale="/mnt/c/Program\ Files/Tailscale/tailscale.exe"' >> ~/.bashrc
        alias tailscale="/mnt/c/Program\ Files/Tailscale/tailscale.exe"

        sudo mkdir -p /Applications/Tailscale.app/Contents/MacOS
        sudo ln -sf "/mnt/c/Program Files/Tailscale/tailscale.exe" /Applications/Tailscale.app/Contents/MacOS/Tailscale
    fi
else
    # Check if nvcc is installed
    if ! command -v /usr/local/cuda/bin/nvcc &> /dev/null && ! command -v nvcc &> /dev/null; then
        read -p "CUDA not found. Do you want to install CUDA 12.6? (y/N): " install_cuda
        if [[ $install_cuda =~ ^[Yy]$ ]]; then
            bash install_cuda12.6.sh
        else
            echo "Skipping CUDA installation."
        fi
    fi
fi

bash cp_dotfiles.sh
bash min_system.sh
bash gitconfig.sh
#bash install_fzf.sh
bash extra_install.sh

bash install_miniconda.sh

# below needs to be done after miniconda install script as script exists after last command
# modify .bashrc
~/miniconda3/bin/conda init bash
# Source the conda.sh script directly so we don't have reopen the terminal
. $HOME/miniconda3/etc/profile.d/conda.sh
conda activate base

# install Poetry
#curl -sSL https://install.python-poetry.org | python3 -

# pip installs
pip install -q nvitop rich

bash install_dl_frameworks.sh

