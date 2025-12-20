#!/usr/bin/env bash
# Build for the CURRENT host architecture only and load into the local 'docker images' store.
# Usage: ./build_local.sh
#   Environment variables:
#     IMAGE         - Image name (default: gpu-devbox)
#     TAG           - Image tag (default: local)
#     BUILD_CONTEXT - Build context directory (default: repo root)
#     BUILDER       - Buildx builder name (default: gpu-devbox-builder)
set -euo pipefail

IMAGE="${IMAGE:-gpu-devbox}"
TAG="${TAG:-local}"
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

echo ">> Building local arch image ${IMAGE}:${TAG}"
echo "   Context:    ${BUILD_CONTEXT}"
echo "   Dockerfile: ${DOCKERFILE}"
echo "   VCS_REF:    ${VCS_REF}"
echo ""

pushd "${BUILD_CONTEXT}" >/dev/null
trap 'popd >/dev/null' EXIT

# --load puts the image into the classic Docker engine store (single-arch only)
docker buildx build \
    --file "${DOCKERFILE}" \
    --builder "${BUILDER}" \
    --build-arg VCS_REF="${VCS_REF}" \
    --progress=plain \
    --load \
    -t "${IMAGE}:${TAG}" \
    "${BUILD_CONTEXT}"

echo ""
echo "Done. Image built: ${IMAGE}:${TAG}"
echo ""
echo "To run (with GPU):"
echo "  ./run.sh"
echo "  # or manually:"
echo "  docker run --rm -it --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 ${IMAGE}:${TAG}"
