#!/usr/bin/env bash
# Build a multi-arch image (amd64, arm64) without pushing.
# Usage: ./build_multiarch.sh
#   Environment variables:
#     IMAGE         - Image name (default: sytelus/cpu-devbox)
#     TAG           - Image tag (default: YYYY.MM.DD)
#     PLATFORMS     - Target platforms (default: linux/amd64,linux/arm64)
#     BUILD_CONTEXT - Build context directory (default: repo root)
#     BUILDER       - Buildx builder name (default: cpu-devbox-builder)
#     CACHE_DIR     - Build cache directory (default: .buildx-cache)
set -euo pipefail

IMAGE=${IMAGE:-"sytelus/cpu-devbox"}
TAG="${TAG:-$(date +%Y.%m.%d)}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEFAULT_CONTEXT=$(cd "${SCRIPT_DIR}/../../.." && pwd)
BUILD_CONTEXT="${BUILD_CONTEXT:-${DEFAULT_CONTEXT}}"
BUILD_CONTEXT=$(cd "${BUILD_CONTEXT}" && pwd)
BUILDER="${BUILDER:-cpu-devbox-builder}"

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

# Use a local buildx cache to avoid requiring registry auth during build-only.
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
