#!/usr/bin/env bash
# Build & push a multi-arch image to Docker Hub (defaults to sytelus/gpu-devbox).
# Usage: ./push_multiarch.sh
#   Environment variables:
#     IMAGE         - Image name (default: sytelus/gpu-devbox)
#     TAG           - Image tag (default: YYYY.MM.DD)
#     PLATFORMS     - Target platforms (default: linux/amd64,linux/arm64)
#     BUILD_CONTEXT - Build context directory (default: repo root)
#     BUILDER       - Buildx builder name (default: gpu-devbox-builder)
#     SKIP_LOGIN    - Set to "1" to skip docker login (for CI environments)
#     INSTALL_PYTORCH_NIGHTLY - Set to "true" to install PyTorch nightly (adds -nightly suffix to tag)
#     INSTALL_VLLM  - Set to "true" to install vLLM
set -euo pipefail

IMAGE="${IMAGE:-sytelus/gpu-devbox}"
BASE_TAG="${TAG:-$(date +%Y.%m.%d)}"
INSTALL_PYTORCH_NIGHTLY="${INSTALL_PYTORCH_NIGHTLY:-false}"
INSTALL_VLLM="${INSTALL_VLLM:-false}"

# Auto-add -nightly suffix if PyTorch nightly is enabled
if [ "${INSTALL_PYTORCH_NIGHTLY}" = "true" ]; then
    TAG="${BASE_TAG}-nightly"
    LATEST_TAG="latest-nightly"
else
    TAG="${BASE_TAG}"
    LATEST_TAG="latest"
fi
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEFAULT_CONTEXT=$(cd "${SCRIPT_DIR}/../../.." && pwd)
BUILD_CONTEXT="${BUILD_CONTEXT:-${DEFAULT_CONTEXT}}"
BUILD_CONTEXT=$(cd "${BUILD_CONTEXT}" && pwd)
BUILDER="${BUILDER:-gpu-devbox-builder}"

# Get VCS reference for image labeling
VCS_REF="${VCS_REF:-$(git -C "${BUILD_CONTEXT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")}"

# Compute relative path to Dockerfile from build context
if [ -z "${DOCKERFILE:-}" ]; then
    if command -v realpath >/dev/null 2>&1; then
        DOCKERFILE=$(realpath --relative-to="${BUILD_CONTEXT}" "${SCRIPT_DIR}/Dockerfile")
    else
        # Fallback to Python if realpath is unavailable (e.g., macOS without coreutils)
        DOCKERFILE=$(python3 -c "import os; print(os.path.relpath('${SCRIPT_DIR}/Dockerfile', '${BUILD_CONTEXT}'))")
    fi
fi

# Docker login (skip if SKIP_LOGIN is set, useful for CI with pre-configured credentials)
if [[ "${SKIP_LOGIN:-0}" != "1" ]]; then
    echo ">> Logging into Docker Hub"
    docker login
fi

echo ""
echo ">> Building & pushing ${IMAGE}:${TAG} and ${IMAGE}:${LATEST_TAG}"
echo "   Platforms:  ${PLATFORMS}"
echo "   Context:    ${BUILD_CONTEXT}"
echo "   Dockerfile: ${DOCKERFILE}"
echo "   VCS_REF:    ${VCS_REF}"
echo "   INSTALL_PYTORCH_NIGHTLY: ${INSTALL_PYTORCH_NIGHTLY}"
echo "   INSTALL_VLLM: ${INSTALL_VLLM}"
echo ""

pushd "${BUILD_CONTEXT}" >/dev/null
trap 'popd >/dev/null' EXIT

docker buildx build \
    --file "${DOCKERFILE}" \
    --builder "${BUILDER}" \
    --build-arg VCS_REF="${VCS_REF}" \
    --build-arg INSTALL_PYTORCH_NIGHTLY="${INSTALL_PYTORCH_NIGHTLY}" \
    --build-arg INSTALL_VLLM="${INSTALL_VLLM}" \
    --platform "${PLATFORMS}" \
    --progress=plain \
    --provenance=true \
    --sbom=true \
    -t "${IMAGE}:${TAG}" \
    -t "${IMAGE}:${LATEST_TAG}" \
    --push \
    "${BUILD_CONTEXT}"

echo ""
echo ">> Multi-arch image pushed: ${IMAGE}:${TAG} and ${IMAGE}:${LATEST_TAG}"
echo ""
echo "To verify:"
echo "  ./verify.sh ${IMAGE}:${TAG}"
