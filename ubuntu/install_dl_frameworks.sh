#!/bin/bash
set -e

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_NAME="x86_64"
        ;;
    aarch64|arm64)
        ARCH_NAME="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Function to detect CUDA version
detect_cuda_version() {
    # Get CUDA version from nvcc if available
    if command -v nvcc &> /dev/null; then
        NVCC_PATH=$(command -v nvcc)
    elif [ -f "/usr/local/cuda/bin/nvcc" ]; then
        NVCC_PATH="/usr/local/cuda/bin/nvcc"
    else
        echo "✗ nvcc not found"
        return 1
    fi

    CUDA_VERSION=$($NVCC_PATH --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
    CUDA_MAJOR=$(echo "$CUDA_VERSION" | cut -d. -f1)
    CUDA_MINOR=$(echo "$CUDA_VERSION" | cut -d. -f2)

    echo "✓ CUDA detected:"
    echo "  - CUDA version: $CUDA_MAJOR.$CUDA_MINOR"
    echo "  - nvcc path: $NVCC_PATH"
    return 0
}


# Install additional frameworks based on architecture
conda install -y -c conda-forge tensorflow
conda install -y -c conda-forge tensorboard keras
# pip uninstall -y transformers datasets wandb accelerate einops tokenizers sentencepiece
pip install -q transformers datasets wandb accelerate einops tokenizers sentencepiece

# Install additional common ML packages
conda install pandas scikit-learn matplotlib jupyter -y


# Function to install PyTorch based on CUDA version and architecture
install_pytorch() {
    local cuda_major=$1
    local cuda_minor=$2

    case $ARCH_NAME in
        "x86_64"|"arm64")
            if [ -n "$cuda_major" ]; then
                # Install CUDA-enabled PyTorch
                conda install pytorch torchvision torchaudio pytorch-cuda="$cuda_major.$cuda_minor" -c pytorch -c nvidia -y
            else
                # Install CPU-only version
                conda install pytorch torchvision torchaudio cpuonly -c pytorch -y
                echo "Installing CPU-only PyTorch as no CUDA was detected"
            fi
            ;;
    esac
}

# Main installation logic
if detect_cuda_version; then
    # nvcc seems to get upgraded to 12.6 even when we installed 12.4 :(, so just install hard coded version
    install_pytorch "12" "4" #  "$CUDA_MAJOR" "$CUDA_MINOR"
else
    install_pytorch "" ""
fi

# Verify installation
python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}')"