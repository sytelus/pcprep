#!/usr/bin/env bash
# Prunes ALL unused Docker data to reclaim disk space.
#
# What it removes:
#   - Unused images (including non-dangling) via --all
#   - Stopped containers, unused networks, and build cache
#   - All unused volumes via --volumes (data-loss for those volumes)
#
# WARNING: This is DESTRUCTIVE for unused volumes; data stored there will be lost.
#
# Usage: ./dockerprune.sh [--force]
#   --force  Skip confirmation prompt (use with caution)
#
# Notes:
#   - Docker will prompt for confirmation unless --force is used
#   - Requires a running Docker daemon and permission to access it
set -euo pipefail

echo "=========== Current Docker Disk Usage ==========="
docker system df

echo ""

FORCE_FLAG=""
if [[ "${1:-}" == "--force" ]] || [[ "${1:-}" == "-f" ]]; then
    FORCE_FLAG="--force"
    echo "WARNING: Running in force mode - no confirmation will be requested!"
    echo ""
fi

echo "This will remove:"
echo "  - All stopped containers"
echo "  - All networks not used by at least one container"
echo "  - All images without at least one container associated to them"
echo "  - All build cache"
echo "  - All volumes not used by at least one container"
echo ""

# shellcheck disable=SC2086
docker system prune --all --volumes ${FORCE_FLAG}

echo ""
echo "=========== Updated Docker Disk Usage ==========="
docker system df
