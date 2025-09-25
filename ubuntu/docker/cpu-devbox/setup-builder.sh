#!/usr/bin/env bash
set -euo pipefail

# Create a BuildKit builder that can cross-build with QEMU emulation.
# On Docker Desktop (Mac/Windows), binfmt is already installed — the binfmt step will be skipped.

BUILDER="${BUILDER:-cpu-devbox-builder}"

echo ">> Ensuring binfmt (for cross-arch emulation) is installed (Linux hosts only)..."
if ! docker buildx version >/dev/null 2>&1; then
  echo "ERROR: docker buildx not available. Upgrade Docker to 24+."; exit 1
fi

# Install binfmt (Linux hosts). This is a no-op on Docker Desktop.
if [[ "$(uname -s)" == "Linux" ]]; then
  docker run --privileged --rm tonistiigi/binfmt --install all || true
fi

if docker buildx ls | grep -qE "^${BUILDER}\b"; then
  echo ">> Builder '${BUILDER}' already exists."
else
  echo ">> Creating builder '${BUILDER}'..."
  docker buildx create --name "${BUILDER}" --driver docker-container --use
fi

echo ">> Bootstrapping builder..."
docker buildx inspect --builder "${BUILDER}" --bootstrap

echo ">> Active builder:"
docker buildx ls
