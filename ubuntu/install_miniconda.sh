#!/bin/bash
set -e

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-py311_24.7.1-0-Linux-x86_64.sh"
        ;;
    aarch64|arm64)
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-py311_24.7.1-0-Linux-aarch64.sh"
        ;;
    ppc64le)
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-py311_24.7.1-0-Linux-ppc64le.sh"
        ;;
    s390x)
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-py311_24.7.1-0-Linux-s390x.sh"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Check if MINICONDA_FILE is set, if not set use the path where we will download it
if [ -z "$MINICONDA_FILE" ]; then
    if [ -z "${NO_NET}" ]; then
        MINICONDA_FILE=~/miniconda3/miniconda.sh
    else
        echo "MINICONDA_FILE is not set but NO_NET is set so won't install miniconda"
        exit 0
    fi
fi

# Create directory for miniconda installation
mkdir -p "$(dirname "$MINICONDA_FILE")"

# Download miniconda installer
wget "$MINICONDA_URL" -O "$MINICONDA_FILE"

# Install miniconda
bash "$MINICONDA_FILE" -b -u -p ~/miniconda3

# Clean up installer
#rm -rf "$MINICONDA_FILE"

# modify .bashrc
~/miniconda3/bin/conda init bash

# Source the conda.sh script directly so we don't have reopen the terminal
. $HOME/miniconda3/etc/profile.d/conda.sh

conda activate base

# update to latest version
# conda update -n base -c defaults conda

# Make sure we have fast solver
# conda config --show solver
# conda install -n base conda-libmamba-solver
# conda config --set solver libmamba