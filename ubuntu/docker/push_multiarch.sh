#!/usr/bin/env bash
set -euo pipefail

# Push a multi-arch image to Docker Hub for user 'sytelus'.
# Assumptions:
# - IMAGE is in the format 'docker_user/repo' (e.g., 'sytelus/cpu-devbox').
# - We always push to Docker Hub and to the same repo.
# - We tag with ${TAG} and also push 'latest'.

IMAGE="${IMAGE:-sytelus/cpu-devbox}"
TAG="${TAG:-$(date +%Y.%m.%d)}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILD_CONTEXT="${BUILD_CONTEXT:-.}"
BUILDER="${BUILDER:-cpu-devbox-builder}"

echo ">> Logging into Docker Hub"
docker login

echo ">> Building & pushing ${IMAGE}:${TAG} and ${IMAGE}:latest"
docker buildx build \
  --builder "${BUILDER}" \
  --platform "${PLATFORMS}" \
  --progress=plain \
  -t "${IMAGE}:${TAG}" \
  -t "${IMAGE}:latest" \
  --push \
  "${BUILD_CONTEXT}"

echo ">> Multi-arch image pushed: ${IMAGE}:${TAG} and ${IMAGE}:latest"
echo ">> To verify:

./verify.sh ${IMAGE}:${TAG}"
