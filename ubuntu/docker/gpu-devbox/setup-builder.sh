#!/usr/bin/env bash
# Create a BuildKit builder that can cross-build with QEMU emulation.
# Run this once before using build_local.sh or build_multiarch.sh.
#
# On Docker Desktop (Mac/Windows), binfmt is already installed — the binfmt step will be skipped.
# On Linux, this installs QEMU user-mode emulation via tonistiigi/binfmt.
#
# Usage: ./setup-builder.sh
#   Environment variables:
#     BUILDER - Builder name (default: gpu-devbox-builder)
set -euo pipefail

BUILDER="${BUILDER:-gpu-devbox-builder}"

echo "=========== Checking Docker Buildx ==========="
if ! docker buildx version >/dev/null 2>&1; then
    echo "ERROR: docker buildx not available." >&2
    echo "  - Docker 24+ includes buildx by default" >&2
    echo "  - Install manually: https://github.com/docker/buildx#installing" >&2
    exit 1
fi
docker buildx version

echo ""
echo "=========== Setting up QEMU (Linux only) ==========="
if [[ "$(uname -s)" == "Linux" ]]; then
    echo "Installing binfmt handlers for cross-architecture builds..."
    if docker run --privileged --rm tonistiigi/binfmt --install all; then
        echo "binfmt handlers installed successfully."
    else
        echo "WARNING: binfmt installation failed. Cross-arch builds may not work." >&2
    fi
else
    echo "Skipping binfmt setup (not required on $(uname -s))."
fi

echo ""
echo "=========== Configuring Builder ==========="
if docker buildx ls | grep -qE "^${BUILDER}\\s"; then
    echo "Builder '${BUILDER}' already exists."
else
    echo "Creating builder '${BUILDER}'..."
    docker buildx create \
        --name "${BUILDER}" \
        --driver docker-container \
        --driver-opt network=host \
        --use
fi

echo ""
echo "=========== Bootstrapping Builder ==========="
docker buildx inspect --builder "${BUILDER}" --bootstrap

echo ""
echo "=========== Available Builders ==========="
docker buildx ls

echo ""
echo "Setup complete. Builder '${BUILDER}' is ready for multi-arch builds."
