#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# Function to check if NVIDIA GPU is available
check_nvidia_gpu() {
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            return 0  # NVIDIA GPU is available
        fi
    fi
    return 1  # NVIDIA GPU is not available
}

# PyTorch and GPU utils install
if check_nvidia_gpu; then
    echo "NVIDIA GPU detected. Installing PyTorch with CUDA support..."
    # conda remove -y pytorch torchvision torchaudio
    conda install -y pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia
    conda install -y -c conda-forge gpustat scikit-learn-intelex py3nvml glances
else
    echo "No NVIDIA GPU detected. Installing PyTorch for CPU only..."
    conda install -y pytorch torchvision torchaudio cpuonly -c pytorch
fi

conda install -y -c conda-forge tensorflow
conda install -y -c conda-forge tensorboard keras
# pip uninstall -y transformers datasets wandb accelerate einops tokenizers sentencepiece
pip install -q transformers datasets wandb accelerate einops tokenizers sentencepiece
