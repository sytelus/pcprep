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
SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEFAULT_CONTEXT=$(cd "${SCRIPT_DIR}/../../.." && pwd)
BUILD_CONTEXT="${BUILD_CONTEXT:-${DEFAULT_CONTEXT}}"
BUILD_CONTEXT=$(cd "${BUILD_CONTEXT}" && pwd)
BUILDER="${BUILDER:-cpu-devbox-builder}"

REL_PATH_PYTHON=${REL_PATH_PYTHON:-python3}
if ! command -v "${REL_PATH_PYTHON}" >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1; then
    REL_PATH_PYTHON=python
  else
    echo "python3 (or python) is required to compute relative paths" >&2
    exit 1
  fi
fi

if [ -z "${DOCKERFILE:-}" ]; then
  DOCKERFILE=$("${REL_PATH_PYTHON}" - "${BUILD_CONTEXT}" "${SCRIPT_DIR}/Dockerfile" <<'PY'
import os
import sys
context = os.path.abspath(sys.argv[1])
dockerfile = os.path.abspath(sys.argv[2])
print(os.path.relpath(dockerfile, context))
PY
)
fi

echo ">> Logging into Docker Hub"
docker login

echo ">> Building & pushing ${IMAGE}:${TAG} and ${IMAGE}:latest"
echo "   Context:   ${BUILD_CONTEXT}"
echo "   Dockerfile:${DOCKERFILE}"
pushd "${BUILD_CONTEXT}" >/dev/null
trap 'popd >/dev/null' EXIT
docker buildx build \
  --file "${DOCKERFILE}" \
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
