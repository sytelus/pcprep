#!/usr/bin/env bash
# Prunes ALL unused Docker data to reclaim disk space.
#
# What it removes:
# - Unused images (including non-dangling) via --all
# - Stopped containers, unused networks, and build cache
# - All unused volumes via --volumes (data-loss for those volumes)
#
# Notes:
# - This is DESTRUCTIVE for unused volumes; data stored there will be lost.
# - Docker will prompt for confirmation (no --force used here).
# - Requires a running Docker daemon and permission to access it (e.g., user in 'docker' group).

docker system prune --all --volumes
