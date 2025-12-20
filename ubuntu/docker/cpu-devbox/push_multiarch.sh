#!/usr/bin/env bash
# Push a multi-arch image to Docker Hub.
# Usage: ./push_multiarch.sh
#   Environment variables:
#     IMAGE      - Image name (default: sytelus/cpu-devbox)
#     TAG        - Image tag (default: YYYY.MM.DD)
#     PLATFORMS  - Target platforms (default: linux/amd64,linux/arm64)
#     SKIP_LOGIN - Set to 1 to skip docker login (for CI with pre-authenticated registries)
set -euo pipefail

IMAGE="${IMAGE:-sytelus/cpu-devbox}"
TAG="${TAG:-$(date +%Y.%m.%d)}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEFAULT_CONTEXT=$(cd "${SCRIPT_DIR}/../../.." && pwd)
BUILD_CONTEXT="${BUILD_CONTEXT:-${DEFAULT_CONTEXT}}"
BUILD_CONTEXT=$(cd "${BUILD_CONTEXT}" && pwd)
BUILDER="${BUILDER:-cpu-devbox-builder}"
SKIP_LOGIN="${SKIP_LOGIN:-0}"

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

if [ "${SKIP_LOGIN}" != "1" ]; then
    echo ">> Logging into Docker Hub"
    docker login
else
    echo ">> Skipping Docker login (SKIP_LOGIN=1)"
fi

echo ">> Building & pushing ${IMAGE}:${TAG} and ${IMAGE}:latest"
echo "   Context:    ${BUILD_CONTEXT}"
echo "   Dockerfile: ${DOCKERFILE}"
echo "   VCS_REF:    ${VCS_REF}"
pushd "${BUILD_CONTEXT}" >/dev/null
trap 'popd >/dev/null' EXIT
docker buildx build \
    --file "${DOCKERFILE}" \
    --builder "${BUILDER}" \
    --build-arg VCS_REF="${VCS_REF}" \
    --platform "${PLATFORMS}" \
    --progress=plain \
    --provenance=true \
    --sbom=true \
    -t "${IMAGE}:${TAG}" \
    -t "${IMAGE}:latest" \
    --push \
    "${BUILD_CONTEXT}"

echo ">> Multi-arch image pushed: ${IMAGE}:${TAG} and ${IMAGE}:latest"
echo ">> To verify: ./verify.sh ${IMAGE}:${TAG}"
