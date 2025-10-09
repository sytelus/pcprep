#!/usr/bin/env bash
# install sequence for TransformerEngine on Ubuntu 24.04 with CUDA 12.8

set -euo pipefail

# install CUDA
sudo bash install_cuda12.8.sh

# make sure to setup paths for cuda 12.8
source /usr/local/bin/use-cuda12.8

# install cuDNN
conda install nvidia::cudnn cuda-version=12

# install NCCL
bash install_nccl.sh

# finally install TransformerEngine
pip3 install --no-build-isolation transformer_engine[pytorch]