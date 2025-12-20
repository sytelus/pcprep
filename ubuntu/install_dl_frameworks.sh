#!/bin/bash
set -eu -o pipefail  # fail if any command failes, -o xtrace to log all commands, -o xtrace

export NO_NET=${NO_NET:-0}

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
    # Get CUDA version from nvidia-smi if available
    if command -v nvidia-smi &> /dev/null; then
        NVCC_PATH=$(command -v nvidia-smi)
    else
        echo "✗ nvidia-smi not found"
        return 1
    fi

    CUDA_VERSION=$($NVCC_PATH | grep "CUDA Version" | sed -n 's/.*CUDA Version: \([0-9]*\.[0-9]*\).*/\1/p')
    if [ -z "$CUDA_VERSION" ]; then
        echo "✗ Unable to detect CUDA version"
        return 1
    fi

    CUDA_MAJOR=$(echo "$CUDA_VERSION" | cut -d. -f1)
    CUDA_MINOR=$(echo "$CUDA_VERSION" | cut -d. -f2)

    echo "✓ CUDA detected:"
    echo "  - CUDA version: $CUDA_MAJOR.$CUDA_MINOR"
    echo "  - nvcc path: $NVCC_PATH"

    # if INSTALL_PYTORCH is non-zero or y then install without prompting
    if [ -n "${INSTALL_PYTORCH:-}" ]; then
        low=$(printf '%s' "$INSTALL_PYTORCH" | tr '[:upper:]' '[:lower:]')
        if echo "$INSTALL_PYTORCH" | grep -Eq '^[1-9][0-9]*$' || [ "$low" = "y" ]; then
            :  # Skip prompt
        else
            read -p "Press Enter to proceed with above (Ctrl+C to terminate)." -n 1 -r
        fi
    else
        read -p "Press Enter to proceed with above (Ctrl+C to terminate)." -n 1 -r
    fi
    echo ""
    return 0
}


# Install additional common ML packages
echo "Installing general data science packages..."
pip install -q pandas scikit-learn matplotlib jupyter

# Install additional frameworks based on architecture
echo "Installing TF and other packages..."
pip install -q tensorflow tensorboard keras

# Function to install PyTorch based on CUDA version and architecture
install_pytorch() {
    local cuda_major=$1
    local cuda_minor=$2

    case $ARCH_NAME in
        "x86_64"|"arm64")
            if [ -n "$cuda_major" ]; then
                echo "Installing PyTorch with CUDA..."
                # Install CUDA-enabled PyTorch
                pip install -q torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu${cuda_major}${cuda_minor}
            else
                echo "Installing CPU-only PyTorch as no CUDA was detected"
                # Install CPU-only version
                # Below  was causing stange error so trying below more verbose way
                PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cpu"
                python3 -m pip install -q torch torchvision torchaudio --index-url "$PYTORCH_INDEX_URL"

            fi
            ;;
    esac
}

if [ "$NO_NET" = "0" ]; then
    # Main installation logic
    if detect_cuda_version; then
        # nvcc has random version than what we installed :(, so just install hard coded version for now.
        install_pytorch "12" "6" #  "$CUDA_MAJOR" "$CUDA_MINOR"
    else
        install_pytorch "" ""
    fi
fi

# pip uninstall -y transformers datasets wandb accelerate einops tokenizers sentencepiece
echo "Installing HF and other packages..."
pip install -q transformers datasets wandb accelerate einops tokenizers sentencepiece lightning

# Verify installation
python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}')"