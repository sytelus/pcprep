#!/bin/bash
#fail if any errors
set -eu -o pipefail -o xtrace # fail if any command failes, log all commands, -o xtrace

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_DEB="amd64"
        ;;
    aarch64|arm64)
        ARCH_DEB="arm64"
        ;;
    armv7l)
        ARCH_DEB="armhf"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Attempt to run a harmless command with sudo
if sudo -n true 2>/dev/null; then
    # install core packages
    sudo apt-get install --assume-yes --no-install-recommends \
        git curl wget xclip xsel xz-utils tar apt-transport-https trash-cli bash-completion \
        npm nodejs \
        tlp powertop tlp-rdw inxi procinfo htop aptitude \
        build-essential cmake libopencv-dev g++ libopenmpi-dev zlib1g-dev \
        fortune-mod sl espeak figlet sysvbanner cowsay oneko cmatrix toilet pi xcowsay aview bb rig weather-util \
        fdupes locate keychain pass micro zlib1g \
        apt-transport-https ca-certificates curl gnupg lsb-release  \
        bzip2 libglib2.0-0 libxext6 libsm6 libxrender1 mercurial subversion \
        virt-what sudo zlib1g g++ freeglut3-dev build-essential libx11-dev \
        libxmu-dev libxi-dev libglu1-mesa libglu1-mesa-dev libfreeimage3 \
        libfreeimage-dev vmtouch neofetch powerstat powertop nvtop \
        tmux screen vim nano

    # Install nvidia-prime only on x86_64 architecture
    if [ "$ARCH" = "x86_64" ]; then
        sudo apt-get install --assume-yes nvidia-prime
    fi

    # update stdc, without this pytest discovery fails
    if [ -n "${NO_NET}" ]; then
        sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
        sudo apt-get -y update
        sudo apt install -y gcc
        sudo apt-get install -y --only-upgrade libstdc++6

        # Check if Azure CLI is installed
        if ! command -v az &> /dev/null; then
            echo "Azure CLI not found. Installing..."
            curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
        fi

        # perms to install az extensions
        az config set extension.use_dynamic_install=yes_without_prompt
        sudo mkdir -p /opt/az/extensions/
        sudo chmod 777 /opt/az/extensions/

        # on ARM architecture wrong azcopy exist in ~/.azure/bin
        bash install_azcopy.sh

        # GitHub CLI
        (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
        && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$ARCH_DEB signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
        && sudo apt update \
        && sudo apt install gh -y

        # # Check if Docker is installed
        # if ! command -v docker &> /dev/null; then
        #     echo "Docker not found. Installing..."
        #     # Add Docker's official GPG key:
        #     sudo apt-get update
        #     sudo apt-get install ca-certificates curl
        #     sudo install -m 0755 -d /etc/apt/keyrings
        #     sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        #     sudo chmod a+r /etc/apt/keyrings/docker.asc

        #     # Add the repository to Apt sources:
        #     echo \
        #         "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        #         $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        #         sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        #     sudo apt-get update -y

        #     sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        #     sudo usermod -aG docker $USER
        #     newgrp docker
        #     # below is needed on Lambda ARM system
        #     sudo setfacl -m user:$USER:rw /var/run/docker.sock
        #     # below is likely not needed
        #     sudo systemctl restart docker
        # else
        #     echo "Docker is already installed."
        # fi

        # install zsh
        sudo apt update
        sudo apt install zsh -y
        # chsh -s $(which zsh) # make zsh default shell

        # install rust
        bash install_rust.sh
    else
        echo "Skipping network-dependent installations due to NO_NET being set"
    fi
else
    echo "Sudo access is not available."
fi

# requires internet
if [ -n "${NO_NET}" ]; then
    # Install micro editor
    pushd "$HOME/.local/bin"
    curl https://getmic.ro | MICRO_DESTDIR="$HOME/.local" sh
    popd

    # install nvm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    source ~/.bashrc
    # install a fresh Node (LTS)
    nvm install --lts
    nvm use --lts

    # Install Zellij
    echo "Installing Zellij..."
    curl -LO https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz
    tar -xvf zellij-x86_64-unknown-linux-musl.tar.gz
    mkdir -p ~/.local/bin
    mv zellij ~/.local/bin/

    # Install rusage (only available for x86_64)
    if [ "$ARCH" = "x86_64" ]; then
        tmp_rusage="$(mktemp)"
        primary="https://justine.lol/rusage/rusage.com"
        fallback="https://github.com/jart/cosmopolitan/raw/master/examples/rusage.com"
        if curl -fsSL "$primary" -o "$tmp_rusage"; then
            install -m 0755 "$tmp_rusage" "$HOME/.local/bin/rusage"
        elif curl -fsSL "$fallback" -o "$tmp_rusage"; then
            install -m 0755 "$tmp_rusage" "$HOME/.local/bin/rusage"
        else
            echo "Skipping rusage installation - download failed from both primary and fallback URLs"
        fi
        rm -f "$tmp_rusage"
    else
        echo "Skipping rusage installation - not available for $ARCH architecture"
    fi
else
    echo "Skipping micro editor and rusage installation due to NO_NET being set"
fi
