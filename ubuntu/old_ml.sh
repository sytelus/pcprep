#!/bin/bash
#fail if any errors
set -e
set -o xtrace

#------------- First install CUDA 10.0 using cuda.sh ------------------------

if [ ! -z "$IS_WSL" ]; then
    conda install -y pytorch torchvision torchaudio cpuonly -c pytorch
else
    conda install -y pytorch torchvision torchaudio pytorch-cuda=11.6 -c pytorch -c nvidia
fi

pip install -q tensorflow
pip install -q tensorboard keras # tensorboardX keras-vis visdom receptivefield optuna
