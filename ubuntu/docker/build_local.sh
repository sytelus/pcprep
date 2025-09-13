#!/usr/bin/env bash
set -euo pipefail

# Build for the CURRENT host architecture only and load into the local 'docker images' store.

IMAGE="${IMAGE:-cpu-devbox}"
TAG="${TAG:-local}"
BUILD_CONTEXT="${BUILD_CONTEXT:-.}"

echo ">> Building local arch image ${IMAGE}:${TAG}"
# --load puts the image into the classic Docker engine store (single-arch only)
docker buildx build \
  --builder "${BUILDER:-cpu-devbox-builder}" \
  --progress=plain \
  --load \
  -t "${IMAGE}:${TAG}" \
  "${BUILD_CONTEXT}"

echo ">> Done. Try: docker run --rm -it ${IMAGE}:${TAG}"
