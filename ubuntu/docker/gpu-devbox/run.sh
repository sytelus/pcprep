#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-gpu-devbox}"
TAG="${TAG:-local}"

# Additional docker args can be passed via RUN_ARGS env or CLI arguments.
RUN_ARGS=()
if [[ -n "${RUN_EXTRA_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  RUN_ARGS+=(${RUN_EXTRA_ARGS})
fi
RUN_ARGS+=("$@")

echo ">> Running ${IMAGE}:${TAG} with GPU access..."
docker run --rm -it \
  --gpus all \
  --ipc=host \
  --ulimit memlock=-1 \
  --ulimit stack=67108864 \
  "${RUN_ARGS[@]}" \
  "${IMAGE}:${TAG}"
