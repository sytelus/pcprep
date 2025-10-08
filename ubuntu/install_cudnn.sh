#!/usr/bin/env bash
# install_cudnn_cuda12x.sh
# Installs cuDNN 9.x (CUDA 12.x build) into /usr/local/cuda-12.8.
# Usage: sudo bash install_cudnn_cuda12x.sh /path/to/cudnn-linux-x86_64-*-cuda12-archive.tar.xz

set -euo pipefail

conda install nvidia::cudnn cuda-version=12