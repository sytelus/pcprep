#!/bin/bash
#fail if any errors
set -e
set -o xtrace

#------------- First install CUDA 10.0 using cuda.sh ------------------------

if [ ! -z "$IS_WSL" ]; then
    conda install -y pytorch torchvision cpuonly -c pytorch
else
    conda install -y pytorch torchvision cudatoolkit=10.0 -c pytorch
fi

pip install -q --pre "tensorflow==1.15.*"
pip install -q tensorboard keras tensorboardX keras-vis visdom receptivefield optuna
