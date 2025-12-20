#!/usr/bin/env bash
# Run the gpu-devbox container with appropriate GPU and memory settings.
# Usage: ./run.sh [docker run options...]
#   Examples:
#     ./run.sh                          # Run with GPU (if available)
#     ./run.sh --no-gpu                 # Force CPU-only mode
#     ./run.sh -v "$PWD:/workspace"     # Mount current directory
set -euo pipefail

IMAGE="${IMAGE:-gpu-devbox}"
TAG="${TAG:-local}"
NO_GPU=false

# Check for --no-gpu flag
for arg in "$@"; do
    if [[ "$arg" == "--no-gpu" ]]; then
        NO_GPU=true
        break
    fi
done

# Additional docker args can be passed via RUN_ARGS env or CLI arguments.
RUN_ARGS=()
if [[ -n "${RUN_EXTRA_ARGS:-}" ]]; then
    # shellcheck disable=SC2206
    RUN_ARGS+=(${RUN_EXTRA_ARGS})
fi

# Filter out --no-gpu from arguments passed to docker
for arg in "$@"; do
    if [[ "$arg" != "--no-gpu" ]]; then
        RUN_ARGS+=("$arg")
    fi
done

# Detect GPU availability
GPU_AVAILABLE=false
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    GPU_AVAILABLE=true
fi

# Build docker run command
DOCKER_CMD=(docker run --rm -it)

if [[ "$NO_GPU" == "true" ]]; then
    echo ">> Running ${IMAGE}:${TAG} in CPU-only mode (--no-gpu specified)..."
elif [[ "$GPU_AVAILABLE" == "true" ]]; then
    echo ">> Running ${IMAGE}:${TAG} with GPU access..."
    DOCKER_CMD+=(--gpus all)
else
    echo ">> Running ${IMAGE}:${TAG} in CPU-only mode (no GPU detected)..."
    echo "   Tip: Install NVIDIA Container Toolkit for GPU support."
fi

# Add memory/IPC settings (useful for both GPU and CPU workloads)
DOCKER_CMD+=(
    --ipc=host
    --ulimit memlock=-1
    --ulimit stack=67108864
)

# Add user-provided arguments and image
if [[ ${#RUN_ARGS[@]} -gt 0 ]]; then
    DOCKER_CMD+=("${RUN_ARGS[@]}")
fi
DOCKER_CMD+=("${IMAGE}:${TAG}")

exec "${DOCKER_CMD[@]}"
