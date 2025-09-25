#!/usr/bin/env bash
set -euo pipefail

# Build a multi-arch image (amd64, arm64) without pushing.

IMAGE=${IMAGE:-"sytelus/cpu-devbox"}
TAG="${TAG:-$(date +%Y.%m.%d)}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILD_CONTEXT="${BUILD_CONTEXT:-.}"
BUILDER="${BUILDER:-cpu-devbox-builder}"

# Use a local buildx cache to avoid requiring registry auth during build-only.
CACHE_DIR="${CACHE_DIR:-.buildx-cache}"
mkdir -p "${CACHE_DIR}"

CACHE_FROM_ARGS=()
if [ -f "${CACHE_DIR}/index.json" ]; then
  CACHE_FROM_ARGS+=(--cache-from "type=local,src=${CACHE_DIR}")
else
  echo ">> Cache: warming new cache at ${CACHE_DIR}"
fi

echo ">> Building (no push) ${IMAGE}:${TAG}"
echo "   Platforms: ${PLATFORMS}"
echo "   Builder:   ${BUILDER}"
echo "   Cache dir: ${CACHE_DIR}"

build_cmd=(
  docker buildx build
  --file Dockerfile_cpu-devbox
  --builder "${BUILDER}"
  --platform "${PLATFORMS}"
  --progress=plain
  --provenance=true
  --sbom=true
)

if [ ${#CACHE_FROM_ARGS[@]} -gt 0 ]; then
  build_cmd+=("${CACHE_FROM_ARGS[@]}")
fi

build_cmd+=(--cache-to "type=local,dest=${CACHE_DIR},mode=max")
build_cmd+=(-t "${IMAGE}:${TAG}")
build_cmd+=("${BUILD_CONTEXT}")

"${build_cmd[@]}"

echo "Multi-arch build completed (artifacts cached via buildx).

NOTE: Docker Buildx may print 'No output specified...' when using the container driver without
      --push/--load. That's expected here—the image is stored in the local build cache so that
      push_multiarch.sh can publish it without rebuilding.

To push:
./push_multiarch.sh IMAGE=${IMAGE} TAG=${TAG} PLATFORMS=${PLATFORMS} BUILDER=${BUILDER}

To test locally on one architecture:
IMAGE=${IMAGE} TAG=${TAG} ./build_local.sh && ./run.sh
"
