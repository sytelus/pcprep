#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-cpu-devbox}"
TAG="${TAG:-local}"

echo ">> Running ${IMAGE}:${TAG} interactively..."
docker run --rm -it "${IMAGE}:${TAG}"
