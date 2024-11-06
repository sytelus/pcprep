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
    echo "Checking CUDA installation..."

    if command -v nvidia-smi &> /dev/null; then
        DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
        CUDA_VERSION=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader)
        # Get CUDA version from nvcc if available
        if command -v nvcc &> /dev/null; then
            CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
            CUDA_MAJOR=$(echo "$CUDA_VERSION" | cut -d. -f1)
            CUDA_MINOR=$(echo "$CUDA_VERSION" | cut -d. -f2)
        else
            # Fallback to driver version to estimate CUDA version
            # Driver 525+ -> CUDA 12.x
            # Driver 450-520 -> CUDA 11.x
            DRIVER_MAJOR=$(echo "$DRIVER_VERSION" | cut -d. -f1)
            if [ "$DRIVER_MAJOR" -ge 525 ]; then
                CUDA_MAJOR="12"
                CUDA_MINOR="0"
            else
                CUDA_MAJOR="11"
                CUDA_MINOR="8"
            fi
        fi

        echo "✓ nvidia-smi detected:"
        echo "  - Driver version: $DRIVER_VERSION"
        echo "  - CUDA version: $CUDA_MAJOR.$CUDA_MINOR"
    else
        echo "✗ nvidia-smi not found"
        return 1
    fi

    if [ -n "$CUDA_MAJOR" ]; then
        echo "→ Using CUDA version $CUDA_MAJOR.$CUDA_MINOR for PyTorch installation"
        return 0
    fi

    echo "✗ No CUDA installation detected"
    return 1
}

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
    install_pytorch "$CUDA_MAJOR" "$CUDA_MINOR"
else
    install_pytorch "" ""
fi

# Install additional frameworks based on architecture
conda install -y -c conda-forge tensorflow
conda install -y -c conda-forge tensorboard keras
# pip uninstall -y transformers datasets wandb accelerate einops tokenizers sentencepiece
pip install -q transformers datasets wandb accelerate einops tokenizers sentencepiece

# Install additional common ML packages
conda install pandas scikit-learn matplotlib jupyter -y

# Verify installation
python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}')"