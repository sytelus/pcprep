#!/usr/bin/env bash
# Display Docker environment information for debugging and diagnostics.
set -euo pipefail

echo "=========== Docker Version ==========="
if ! docker --version; then
    echo "ERROR: Docker is not installed or not accessible." >&2
    exit 1
fi

echo ""
echo "=========== Docker Root Directory ==========="
docker info 2>/dev/null | sed -n 's/ *Docker Root Dir: //p' || echo "Unable to determine"

echo ""
echo "=========== Docker Disk Usage ==========="
docker system df 2>/dev/null || echo "Unable to get disk usage"

echo ""
echo "=========== BuildX Plugin ==========="
if docker buildx version >/dev/null 2>&1; then
    docker buildx version
else
    echo "WARNING: Docker Buildx not available. Install Docker 24+ or the buildx plugin."
fi

echo ""
echo "=========== Available Builders ==========="
docker buildx ls 2>/dev/null || echo "No builders available"

echo ""
echo "=========== NVIDIA Container Toolkit ==========="
if command -v nvidia-container-cli >/dev/null 2>&1; then
    nvidia-container-cli info 2>/dev/null || echo "NVIDIA Container Toolkit installed but not functional"
elif docker info 2>/dev/null | grep -qi nvidia; then
    echo "NVIDIA runtime detected in Docker"
else
    echo "NVIDIA Container Toolkit not detected (required for GPU access)"
fi
