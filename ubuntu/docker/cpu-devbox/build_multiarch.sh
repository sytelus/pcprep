#!/usr/bin/env bash
set -euo pipefail

# Build a multi-arch image (amd64, arm64) without pushing.

IMAGE=${IMAGE:-"sytelus/cpu-devbox"}
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
echo "   Platforms: ${PLATFORMS}"
echo "   Builder:   ${BUILDER}"
echo "   Cache dir: ${CACHE_DIR_ABS}"
echo "   Context:   ${BUILD_CONTEXT}"
echo "   Dockerfile:${DOCKERFILE}"

pushd "${BUILD_CONTEXT}" >/dev/null
trap 'popd >/dev/null' EXIT

build_cmd=(
  docker buildx build
  --file "${DOCKERFILE}"
  --builder "${BUILDER}"
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

"${build_cmd[@]}"

echo "Multi-arch build completed (artifacts cached via buildx).

NOTE: Docker Buildx may print 'No output specified...' when using the container driver without
      --push/--load. That's expected here—the image is stored in the local build cache so that
      push_multiarch.sh can publish it without rebuilding.

To push:
IMAGE=${IMAGE} TAG=${TAG} PLATFORMS=${PLATFORMS} BUILDER=${BUILDER} ./push_multiarch.sh

To test locally on one architecture:
IMAGE=${IMAGE} TAG=${TAG} ./build_local.sh && ./run.sh
"
