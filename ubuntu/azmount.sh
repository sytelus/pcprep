#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_PATH=${AZMOUNT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/pcprep/azmount.yaml}
MOUNT_POINT=${AZMOUNT_POINT:-$HOME/azblob}
CACHE_DIR=${AZMOUNT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/blobfuse2}

[[ $MOUNT_POINT == /* && $MOUNT_POINT != / && ! -L $MOUNT_POINT ]] \
  || { echo "Mount point must be an absolute, non-symlink directory below /: $MOUNT_POINT" >&2; exit 2; }
[[ $CACHE_DIR == /* && $CACHE_DIR != / && ! -L $CACHE_DIR ]] \
  || { echo "Cache path must be an absolute, non-symlink directory below /: $CACHE_DIR" >&2; exit 2; }
[[ ! -e $MOUNT_POINT || -d $MOUNT_POINT ]] \
  || { echo "Mount point is not a directory: $MOUNT_POINT" >&2; exit 2; }
[[ ! -e $CACHE_DIR || -d $CACHE_DIR ]] \
  || { echo "Cache path is not a directory: $CACHE_DIR" >&2; exit 2; }

for cmd in blobfuse2 find install mountpoint stat; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd is required" >&2; exit 1; }
done
[[ -f $CONFIG_PATH ]] || { echo "Missing config: $CONFIG_PATH" >&2; exit 1; }
[[ $(stat -c '%u' "$CONFIG_PATH") = "$(id -u)" ]] \
  || { echo "Config must be owned by the current user: $CONFIG_PATH" >&2; exit 1; }
CONFIG_MODE=$(stat -c '%a' "$CONFIG_PATH")
(( 8#$CONFIG_MODE <= 8#600 )) \
  || { echo "Config permissions must be 0600 or stricter: $CONFIG_PATH ($CONFIG_MODE)" >&2; exit 1; }
grep -Eq '^[[:space:]]*mode:[[:space:]]*msi[[:space:]]*(#.*)?$' "$CONFIG_PATH" \
  || { echo "Refusing a plaintext-key config; use managed identity mode." >&2; exit 1; }
! grep -Eq '^[[:space:]]*mode:[[:space:]]*(key|sas)[[:space:]]*(#.*)?$|^[[:space:]]*account-key:[[:space:]]*[^[:space:]#]+' "$CONFIG_PATH" \
  || { echo "Refusing a config that contains an account key." >&2; exit 1; }

if mountpoint -q "$MOUNT_POINT"; then
  echo "Already mounted: $MOUNT_POINT"
  exit 0
fi
install -d -m 0700 "$MOUNT_POINT" "$CACHE_DIR"
[[ -z $(find "$MOUNT_POINT" -mindepth 1 -print -quit) ]] \
  || { echo "Mount point must be empty: $MOUNT_POINT" >&2; exit 1; }
blobfuse2 mount "$MOUNT_POINT" --config-file="$CONFIG_PATH"
mountpoint -q "$MOUNT_POINT" || { echo "Blobfuse mount verification failed" >&2; exit 1; }
echo "Mounted Azure Blob Storage at $MOUNT_POINT"
