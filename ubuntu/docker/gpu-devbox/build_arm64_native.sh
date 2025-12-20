#!/usr/bin/env bash
# Build for ARM64 on native ARM64 hardware (10x faster than QEMU emulation).
#
# This script is designed to run on native ARM64 machines such as:
#   - Apple Silicon Macs (M1/M2/M3/M4)
#   - AWS Graviton instances
#   - Ampere Altra servers
#   - Raspberry Pi 4/5 (limited by RAM)
#
# Usage: ./build_arm64_native.sh
#   Environment variables:
#     IMAGE         - Image name (default: gpu-devbox)
#     TAG           - Image tag (default: arm64-native)
#     BUILD_CONTEXT - Build context directory (default: repo root)
#     PUSH          - Set to "1" to push after building
#
# Prerequisites:
#   - Docker 24+ with Buildx
#   - Running on native ARM64 hardware
#   - For GPU support: NVIDIA Jetson or ARM64 GPU server
#
# Note: The NVIDIA base image may have limited ARM64 support. Some features
# like flash-attn are not available on ARM64.
set -euo pipefail

# Verify we're on ARM64
ARCH=$(uname -m)
if [[ "${ARCH}" != "aarch64" && "${ARCH}" != "arm64" ]]; then
    echo "ERROR: This script is designed for native ARM64 builds." >&2
    echo "       Detected architecture: ${ARCH}" >&2
    echo "       Use build_multiarch.sh for cross-compilation instead." >&2
    exit 1
fi

IMAGE="${IMAGE:-gpu-devbox}"
TAG="${TAG:-arm64-native}"
SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEFAULT_CONTEXT=$(cd "${SCRIPT_DIR}/../../.." && pwd)
BUILD_CONTEXT="${BUILD_CONTEXT:-${DEFAULT_CONTEXT}}"
BUILD_CONTEXT=$(cd "${BUILD_CONTEXT}" && pwd)
PUSH="${PUSH:-0}"

# Get VCS reference for image labeling
VCS_REF="${VCS_REF:-$(git -C "${BUILD_CONTEXT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")}"

# Compute relative path to Dockerfile from build context
if [ -z "${DOCKERFILE:-}" ]; then
    if command -v realpath >/dev/null 2>&1; then
        DOCKERFILE=$(realpath --relative-to="${BUILD_CONTEXT}" "${SCRIPT_DIR}/Dockerfile")
    else
        DOCKERFILE=$(python3 -c "import os; print(os.path.relpath('${SCRIPT_DIR}/Dockerfile', '${BUILD_CONTEXT}'))")
    fi
fi

echo "=========== ARM64 Native Build ==========="
echo "Architecture: ${ARCH}"
echo "Image:        ${IMAGE}:${TAG}"
echo "Context:      ${BUILD_CONTEXT}"
echo "Dockerfile:   ${DOCKERFILE}"
echo "VCS_REF:      ${VCS_REF}"
echo ""

pushd "${BUILD_CONTEXT}" >/dev/null
trap 'popd >/dev/null' EXIT

# Check if buildx is available
if docker buildx version >/dev/null 2>&1; then
    echo "Using Docker Buildx..."

    BUILD_CMD=(
        docker buildx build
        --file "${DOCKERFILE}"
        --platform "linux/arm64"
        --build-arg VCS_REF="${VCS_REF}"
        --progress=plain
        -t "${IMAGE}:${TAG}"
    )

    # Can't use --load and --push together; choose one based on PUSH flag
    if [[ "${PUSH}" == "1" ]]; then
        BUILD_CMD+=(--push)
        echo "Will push after build..."
    else
        BUILD_CMD+=(--load)
    fi

    BUILD_CMD+=("${BUILD_CONTEXT}")
    "${BUILD_CMD[@]}"
else
    echo "Using standard Docker build..."
    docker build \
        --file "${DOCKERFILE}" \
        --build-arg VCS_REF="${VCS_REF}" \
        --build-arg TARGETARCH=arm64 \
        --build-arg TARGETPLATFORM=linux/arm64 \
        -t "${IMAGE}:${TAG}" \
        "${BUILD_CONTEXT}"

    if [[ "${PUSH}" == "1" ]]; then
        echo "Pushing ${IMAGE}:${TAG}..."
        docker push "${IMAGE}:${TAG}"
    fi
fi

echo ""
echo "=========== Build Complete ==========="
echo "Image: ${IMAGE}:${TAG}"
echo ""
echo "To run:"
echo "  docker run --rm -it ${IMAGE}:${TAG}"
echo ""
echo "To run with GPU (NVIDIA Jetson or ARM64 GPU server):"
echo "  docker run --rm -it --runtime nvidia ${IMAGE}:${TAG}"
