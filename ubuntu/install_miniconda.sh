#!/bin/bash
set -eu -o pipefail -o xtrace # fail if any command failes, log all commands, -o xtrace

export NO_NET=${NO_NET:-0}

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
    if [ "$NO_NET" = "0" ]; then
        # use target download path
        MINICONDA_FILE=~/miniconda3/miniconda.sh

        # Create directory for miniconda installation
        mkdir -p "$(dirname "$MINICONDA_FILE")"

        # Download miniconda installer
        wget "$MINICONDA_URL" -O "$MINICONDA_FILE"
    else
        echo "MINICONDA_FILE is not set but NO_NET is set so won't install miniconda"
        exit 0
    fi
fi

# Install miniconda
bash "$MINICONDA_FILE" -b -u -p ~/miniconda3

# !!!!!!! lines after this won't be executed as script exits after last command !!!!!!

# Clean up installer
#rm -rf "$MINICONDA_FILE"

# update to latest version
# conda update -n base -c defaults conda

# Make sure we have fast solver
# conda config --show solver
# conda install -n base conda-libmamba-solver
# conda config --set solver libmamba