#!/bin/bash
#fail if any errors
set -e
set -o xtrace



# Attempt to run a harmless command with sudo
if sudo -n true 2>/dev/null; then
      # install core packages
      sudo apt-get install --assume-yes --no-install-recommends \
            git curl wget xclip xz-utils tar apt-transport-https trash-cli bash-completion \
            tlp powertop tlp-rdw inxi procinfo nvidia-prime htop aptitude \
            build-essential cmake libopencv-dev g++ libopenmpi-dev zlib1g-dev \
            fortune-mod sl espeak figlet sysvbanner cowsay oneko cmatrix toilet pi xcowsay aview bb rig weather-util \
            fdupes locate keychain pass micro zlib1g \
            apt-transport-https ca-certificates curl gnupg lsb-release  \
            bzip2 libglib2.0-0 libxext6 libsm6 libxrender1 mercurial subversion \
            virt-what sudo zlib1g g++ freeglut3-dev build-essential libx11-dev \
            libxmu-dev libxi-dev libglu1-mesa libglu1-mesa-dev libfreeimage3 \
            libfreeimage-dev vmtouch neofetch powerstat powertop

      # removed nvtop, gpustat

      # update stdc, without this pytest discovery fails
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
      sudo chmod 777 /opt/az/extensions/

      # GitHub CLI
      (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
      && sudo mkdir -p -m 755 /etc/apt/keyrings \
      && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
      && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
      && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
      && sudo apt update \
      && sudo apt install gh -y
else
    echo "Sudo access is not available."
fi


# Install micro editor
cd "$HOME/.local/bin" || exit
curl https://getmic.ro | MICRO_DESTDIR="$HOME/.local" sh

# Install rusage
curl -o "$HOME/.local/bin/rusage" https://justine.lol/rusage/rusage.com
chmod +x "$HOME/.local/bin/rusage"
