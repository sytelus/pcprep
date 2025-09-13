#!/usr/bin/env bash
set -euo pipefail

# Push a multi-arch image (amd64, arm64, arm/v7) to Docker Hub.
# - Tags: pushes both ${TAG} and latest
# - Performs docker login using the username parsed from IMAGE
# - Uses the correct Docker Hub URL

: "${IMAGE:?Set IMAGE, e.g. docker.io/yourname/cpu-devbox or yourname/cpu-devbox}"
TAG="${TAG:-$(date +%Y.%m.%d)}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64,linux/arm/v7}"
BUILD_CONTEXT="${BUILD_CONTEXT:-.}"
BUILDER="${BUILDER:-cpu-devbox-builder}"

# Optional registry cache to speed up subsequent builds:
CACHE_IMAGE="${CACHE_IMAGE:-${IMAGE}:buildcache}"

echo ">> Preparing to push multi-arch image for ${IMAGE}:${TAG} (and latest)"
echo "   Platforms: ${PLATFORMS}"
echo "   Builder:   ${BUILDER}"

# Parse registry, user, and repo from IMAGE
# Accept forms: docker.io/user/repo OR user/repo
parse_image() {
  local img="$1"
  local registry remainder user repo
  IFS='/' read -r first second rest <<<"$img"
  if [[ "$first" == *.* || "$first" == *:* || "$first" == "localhost" ]]; then
    registry="$first"
    remainder="$second/${rest:-}"
  else
    registry="docker.io"
    remainder="$img"
  fi
  user="$(echo "$remainder" | cut -d/ -f1)"
  repo="$(echo "$remainder" | cut -d/ -f2-)"
  echo "$registry" "$user" "$repo"
}

REGISTRY USER REPO=$(parse_image "$IMAGE")
if [ -z "$USER" ] || [ -z "$REPO" ]; then
  echo "IMAGE must include user and repo, e.g. yourname/repo or docker.io/yourname/repo" >&2
  exit 1
fi

echo ">> Logging into $REGISTRY as $USER"
if [ "$REGISTRY" = "docker.io" ]; then
  docker login -u "$USER"
else
  docker login "$REGISTRY" -u "$USER"
fi

echo ">> Building & pushing ${IMAGE}:${TAG} and ${IMAGE}:latest"
docker buildx build \
  --builder "${BUILDER}" \
  --platform "${PLATFORMS}" \
  --progress=plain \
  --provenance=true \
  --sbom=true \
  --cache-from "type=registry,ref=${CACHE_IMAGE}" \
  --cache-to   "type=registry,ref=${CACHE_IMAGE},mode=max" \
  -t "${IMAGE}:${TAG}" \
  -t "${IMAGE}:latest" \
  --push \
  "${BUILD_CONTEXT}"

echo ">> Multi-arch image pushed: ${IMAGE}:${TAG} and ${IMAGE}:latest"
echo ">> Tip: ubuntu/docker/verify.sh ${IMAGE}:${TAG}"

