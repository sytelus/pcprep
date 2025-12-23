#!/usr/bin/env bash
# Build a multi-arch image (amd64, arm64) without pushing.
# Usage: ./build_multiarch.sh
#   Environment variables:
#     IMAGE         - Image name (default: sytelus/gpu-devbox)
#     TAG           - Image tag (default: 25.11-py3, matching base NVIDIA image)
#     PLATFORMS     - Target platforms (default: linux/amd64,linux/arm64)
#     BUILD_CONTEXT - Build context directory (default: repo root)
#     BUILDER       - Buildx builder name (default: gpu-devbox-builder)
#     CACHE_DIR     - Build cache directory (default: .buildx-cache)
#     INSTALL_PYTORCH_NIGHTLY - Set to "true" to install PyTorch nightly (adds -nightly suffix to tag)
#     INSTALL_VLLM  - Set to "true" to install vLLM
set -euo pipefail

IMAGE=${IMAGE:-"sytelus/gpu-devbox"}
BASE_TAG="${TAG:-25.11-py3}"
INSTALL_PYTORCH_NIGHTLY="${INSTALL_PYTORCH_NIGHTLY:-false}"
INSTALL_VLLM="${INSTALL_VLLM:-false}"

# Auto-add -nightly suffix if PyTorch nightly is enabled
if [ "${INSTALL_PYTORCH_NIGHTLY}" = "true" ]; then
    TAG="${BASE_TAG}-nightly"
else
    TAG="${BASE_TAG}"
fi
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEFAULT_CONTEXT=$(cd "${SCRIPT_DIR}/../../.." && pwd)
BUILD_CONTEXT="${BUILD_CONTEXT:-${DEFAULT_CONTEXT}}"
BUILD_CONTEXT=$(cd "${BUILD_CONTEXT}" && pwd)
BUILDER="${BUILDER:-gpu-devbox-builder}"

# Set up logging
LOG_DIR="${LOG_DIR:-${SCRIPT_DIR}/logs}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/build_$(date +%Y%m%d_%H%M%S).log"

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

CACHE_DIR="${CACHE_DIR:-.buildx-cache}"
if [[ "${CACHE_DIR}" = /* ]]; then
    CACHE_DIR_ABS="${CACHE_DIR}"
else
    CACHE_DIR_ABS="${BUILD_CONTEXT}/${CACHE_DIR}"
fi
mkdir -p "${CACHE_DIR_ABS}"

CACHE_FROM_ARGS=()
if [ -f "${CACHE_DIR_ABS}/index.json" ]; then
    CACHE_FROM_ARGS+=(--cache-from "type=local,src=${CACHE_DIR_ABS}")
else
    echo ">> Cache: warming new cache at ${CACHE_DIR_ABS}"
fi

echo ">> Building (no push) ${IMAGE}:${TAG}"
echo "   Platforms:  ${PLATFORMS}"
echo "   Builder:    ${BUILDER}"
echo "   Cache dir:  ${CACHE_DIR_ABS}"
echo "   Context:    ${BUILD_CONTEXT}"
echo "   Dockerfile: ${DOCKERFILE}"
echo "   VCS_REF:    ${VCS_REF}"
echo "   Log file:   ${LOG_FILE}"
echo "   INSTALL_PYTORCH_NIGHTLY: ${INSTALL_PYTORCH_NIGHTLY}"
echo "   INSTALL_VLLM: ${INSTALL_VLLM}"
echo ""

# Start logging (tee to both console and file)
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "=== Build started at $(date) ==="

pushd "${BUILD_CONTEXT}" >/dev/null
trap 'popd >/dev/null' EXIT

build_cmd=(
    docker buildx build
    --file "${DOCKERFILE}"
    --builder "${BUILDER}"
    --build-arg VCS_REF="${VCS_REF}"
    --build-arg INSTALL_PYTORCH_NIGHTLY="${INSTALL_PYTORCH_NIGHTLY}"
    --build-arg INSTALL_VLLM="${INSTALL_VLLM}"
    --platform "${PLATFORMS}"
    --progress=plain
    --provenance=true
    --sbom=true
)

if [ ${#CACHE_FROM_ARGS[@]} -gt 0 ]; then
    build_cmd+=("${CACHE_FROM_ARGS[@]}")
fi

build_cmd+=(--cache-to "type=local,dest=${CACHE_DIR_ABS},mode=max")
build_cmd+=(-t "${IMAGE}:${TAG}")
build_cmd+=("${BUILD_CONTEXT}")

"${build_cmd[@]}" || BUILD_EXIT_CODE=$?
BUILD_EXIT_CODE=${BUILD_EXIT_CODE:-0}

echo ""
echo "=== Build finished at $(date) ==="
echo ""
if [ ${BUILD_EXIT_CODE} -eq 0 ]; then
    echo "Multi-arch build completed (artifacts cached via buildx)."
    echo ""
    echo "To push:"
    echo "  IMAGE=${IMAGE} TAG=${TAG} ./push_multiarch.sh"
    echo ""
    echo "To test locally with GPU:"
    echo "  ./build_local.sh && ./run.sh"
else
    echo "Build FAILED with exit code ${BUILD_EXIT_CODE}"
fi
echo ""
echo "=========================================="
echo "Build log saved to: ${LOG_FILE}"
echo "=========================================="

exit ${BUILD_EXIT_CODE}
