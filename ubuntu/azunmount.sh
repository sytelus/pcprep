#!/usr/bin/env bash
set -Eeuo pipefail

MOUNT_POINT=${AZMOUNT_POINT:-$HOME/azblob}
[[ $MOUNT_POINT == /* && $MOUNT_POINT != / && ! -L $MOUNT_POINT ]] \
  || { echo "Refusing unsafe mount point: $MOUNT_POINT" >&2; exit 2; }
command -v blobfuse2 >/dev/null 2>&1 || { echo "blobfuse2 is required" >&2; exit 1; }
if mountpoint -q "$MOUNT_POINT"; then
  blobfuse2 unmount "$MOUNT_POINT"
  mountpoint -q "$MOUNT_POINT" && { echo "Unmount verification failed" >&2; exit 1; }
  echo "Unmounted $MOUNT_POINT"
else
  echo "Not mounted: $MOUNT_POINT"
fi
