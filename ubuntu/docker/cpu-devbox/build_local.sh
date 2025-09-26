#!/usr/bin/env bash
set -euo pipefail

# Build for the CURRENT host architecture only and load into the local 'docker images' store.

IMAGE="${IMAGE:-cpu-devbox}"
TAG="${TAG:-local}"
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

echo ">> Building local arch image ${IMAGE}:${TAG}"
echo "   Context:   ${BUILD_CONTEXT}"
echo "   Dockerfile:${DOCKERFILE}"
pushd "${BUILD_CONTEXT}" >/dev/null
trap 'popd >/dev/null' EXIT
# --load puts the image into the classic Docker engine store (single-arch only)
docker buildx build \
  --file "${DOCKERFILE}" \
  --builder "${BUILDER}" \
  --progress=plain \
  --load \
  -t "${IMAGE}:${TAG}" \
  "${BUILD_CONTEXT}"

echo "Done.

To run use:
docker run --rm -it ${IMAGE}:${TAG}"
