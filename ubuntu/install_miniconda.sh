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

# install mini conda with Python 3.11 (3.12 has breaking changes with imp module)
mkdir -p ~/miniconda3
wget "$MINICONDA_URL" -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
rm -rf ~/miniconda3/miniconda.sh

# modify .bashrc
~/miniconda3/bin/conda init bash

# update to latest version
# conda update -n base -c defaults conda

# Make sure we have fast solver
# conda config --show solver
# conda install -n base conda-libmamba-solver
# conda config --set solver libmamba