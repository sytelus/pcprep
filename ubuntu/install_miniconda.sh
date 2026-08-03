#!/usr/bin/env bash
set -Eeuo pipefail

export NO_NET=${NO_NET:-0}
export MINICONDA_FILE=${MINICONDA_FILE:-}
export MINICONDA_VERSION=${MINICONDA_VERSION:-26.5.3-1}
export MINICONDA_PYTHON_SERIES=${MINICONDA_PYTHON_SERIES:-py313}
export PYTHON_VERSION=${PYTHON_VERSION:-3.14}

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_PYTHON_SERIES}_${MINICONDA_VERSION}-Linux-x86_64.sh"
        ;;
    aarch64|arm64)
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_PYTHON_SERIES}_${MINICONDA_VERSION}-Linux-aarch64.sh"
        ;;
    ppc64le|s390x)
        echo "Unsupported architecture for the current Python $PYTHON_VERSION stack: $ARCH" >&2
        echo "Anaconda's defaults channel does not publish Python $PYTHON_VERSION for $ARCH." >&2
        exit 1
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Check if MINICONDA_FILE is set, if not set use the path where we will download it
if [ -z "$MINICONDA_FILE" ]; then
    if [ "$NO_NET" = "0" ]; then
        # use target download path
        MINICONDA_FILE="$HOME/miniconda3/miniconda.sh"

        # Create directory for miniconda installation
        mkdir -p "$(dirname "$MINICONDA_FILE")"

        # Download miniconda installer
        wget "$MINICONDA_URL" -O "$MINICONDA_FILE"
    else
        echo "MINICONDA_FILE is not set but NO_NET is set so won't install miniconda"
        exit 0
    fi
fi

# Install miniconda
bash "$MINICONDA_FILE" -b -u -p "$HOME/miniconda3"

CONDA="$HOME/miniconda3/bin/conda"
CONDA_PYTHON="$HOME/miniconda3/bin/python"
[ -x "$CONDA" ] || { echo "Miniconda installation did not create $CONDA" >&2; exit 1; }

# The latest Miniconda installer currently bootstraps with Python 3.13. Move
# base to the latest stable Python feature series requested by the orchestrator.
if [ "$NO_NET" = "0" ]; then
    "$CONDA" install --yes "python=$PYTHON_VERSION" pip
fi

ACTUAL_PYTHON_VERSION=$(
    "$CONDA_PYTHON" -c 'import platform; print(platform.python_version())'
)
case "$ACTUAL_PYTHON_VERSION" in
    "$PYTHON_VERSION"|"$PYTHON_VERSION".*) ;;
    *)
        echo "Expected Python $PYTHON_VERSION.x, found $ACTUAL_PYTHON_VERSION in Miniconda base." >&2
        [ "$NO_NET" = "0" ] \
            || echo "An offline installer must already contain the requested Python version." >&2
        exit 1
        ;;
esac

"$CONDA" --version
"$CONDA_PYTHON" --version
