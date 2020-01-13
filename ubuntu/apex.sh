#!/bin/bash
#fail if any errors
set -e
set -o xtrace

mkdir -p ~/GitHubSrc
pushd ~/GitHubSrc
git clone https://github.com/NVIDIA/apex
cd apex
pip install -v --no-cache-dir --global-option="--cpp_ext" --global-option="--cuda_ext" ./
popd
