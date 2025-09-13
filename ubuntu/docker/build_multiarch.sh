#!/usr/bin/env bash
set -euo pipefail

# Build a multi-arch image (amd64, arm64, arm/v7) without pushing.

IMAGE=${IMAGE:-"sytelus/cpu-devbox"}
TAG="${TAG:-$(date +%Y.%m.%d)}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64,linux/arm/v7}"
BUILD_CONTEXT="${BUILD_CONTEXT:-.}"
BUILDER="${BUILDER:-cpu-devbox-builder}"

# Use a local buildx cache to avoid requiring registry auth during build-only.
CACHE_DIR="${CACHE_DIR:-.buildx-cache}"

echo ">> Building (no push) ${IMAGE}:${TAG}"
echo "   Platforms: ${PLATFORMS}"
echo "   Builder:   ${BUILDER}"

docker buildx build \
  --builder "${BUILDER}" \
  --platform "${PLATFORMS}" \
  --progress=plain \
  --provenance=true \
  --sbom=true \
  --cache-from "type=local,src=${CACHE_DIR}" \
  --cache-to   "type=local,dest=${CACHE_DIR},mode=max" \
  -t "${IMAGE}:${TAG}" \
  "${BUILD_CONTEXT}"

echo "Multi-arch build completed (artifacts cached via buildx)."
echo "To push:
./push_multiarch.sh IMAGE=${IMAGE} TAG=${TAG} PLATFORMS=${PLATFORMS} BUILDER=${BUILDER}"
