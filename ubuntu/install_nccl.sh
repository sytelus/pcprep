#!/usr/bin/env bash
# install nccl.h and libs needed for TransformerEngine

set -euo pipefail

# 1) Install NCCL runtime + headers
sudo apt-get update
# See available versions (handy for pinning):
apt-cache policy libnccl2 libnccl-dev | sed -n '1,120p'
# Install the latest from the CUDA repo:
sudo apt-get install -y libnccl2 libnccl-dev

# 2) Verify headers/libs landed here:
ls /usr/include/nccl.h
ls /usr/lib/x86_64-linux-gnu/libnccl.so*