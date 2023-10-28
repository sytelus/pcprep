#!/bin/bash
#fail if any errors
set -e
set -o xtrace

conda install -y pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia
conda install -y -c conda-forge tensorflow
conda install -y -c conda-forge tensorboard keras
conda install -y -c conda-forge gpustat scikit-learn-intelex py3nvml glances
pip install -q transformers datasets wandb accelerate einops tokenizers sentencepiece