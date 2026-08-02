#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage:
  docker-move-data.sh <NEW_DATA_ROOT> [--rootless] [--dry-run] [--bind-mount] [--delete-old]

Safely copy Docker's data store, verify it, switch Docker, and retain the old
store unless --delete-old is explicit. --dry-run performs no persistent write,
service operation, mount, chmod, or configuration change.

Modes:
  rootful (default)  Run the real migration as root.
  --rootless         Run as the owning non-root user; uses user daemon.json.
  --bind-mount       Rootful only. Persist a verified bind mount in /etc/fstab.
USAGE
}

die() { echo "ERROR: $*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

[[ $# -ge 1 ]] || { usage; exit 1; }
NEW_ROOT_INPUT=$1
shift
ROOTLESS=0
DRY_RUN=0
BIND_MOUNT=0
DELETE_OLD=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rootless) ROOTLESS=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --bind-mount) BIND_MOUNT=1 ;;
    --delete-old) DELETE_OLD=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

require_cmd docker
require_cmd pgrep
require_cmd realpath
require_cmd rsync

if (( ROOTLESS )); then
  [[ ${EUID:-$(id -u)} -ne 0 ]] || die "--rootless must not run under sudo/root"
  (( BIND_MOUNT == 0 )) || die "--bind-mount is not supported for rootless Docker"
  DOCKER_CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/docker"
  DAEMON_JSON="$DOCKER_CFG_DIR/daemon.json"
  CURRENT_DEFAULT="${XDG_DATA_HOME:-$HOME/.local/share}/docker"
  SERVICE_CTL=(systemctl --user)
  SERVICE_UNITS=(docker.service docker.socket)
else
  if (( DRY_RUN == 0 )); then
    [[ ${EUID:-$(id -u)} -eq 0 ]] || die "rootful migration requires sudo/root"
  fi
  DOCKER_CFG_DIR=/etc/docker
  DAEMON_JSON="$DOCKER_CFG_DIR/daemon.json"
  CURRENT_DEFAULT=/var/lib/docker
  SERVICE_CTL=(systemctl)
  SERVICE_UNITS=(docker.service docker.socket containerd.service)
fi

DOCKER_RUNNING=0
if (( ROOTLESS )); then
  pgrep -u "$(id -u)" -x dockerd >/dev/null 2>&1 && DOCKER_RUNNING=1
else
  pgrep -u 0 -x dockerd >/dev/null 2>&1 && DOCKER_RUNNING=1
fi

if (( DRY_RUN && DOCKER_RUNNING == 0 )); then
  # Avoid socket-activating Docker during a no-change preview. Read a configured
  # data-root if possible; otherwise the documented platform default is safe to
  # inspect without starting a service.
  if [[ -s $DAEMON_JSON ]]; then
    require_cmd jq
    PROBED_ROOT=$(jq -er '."data-root" // empty' "$DAEMON_JSON") \
      || die "cannot determine data-root from $DAEMON_JSON without starting Docker"
  else
    PROBED_ROOT=$CURRENT_DEFAULT
  fi
else
  PROBED_ROOT=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null) \
    || die "docker info failed; refusing to guess the active data-root"
  [[ -n $PROBED_ROOT ]] || die "docker info returned an empty data-root"
fi

CURRENT_ROOT=$(realpath -m -- "${PROBED_ROOT:-$CURRENT_DEFAULT}")
NEW_ROOT=$(realpath -m -- "$NEW_ROOT_INPUT")
[[ $CURRENT_ROOT != / && $NEW_ROOT != / ]] || die "filesystem root is not a valid Docker data path"
[[ -d $CURRENT_ROOT ]] || die "current Docker data-root does not exist: $CURRENT_ROOT"
[[ $CURRENT_ROOT != "$NEW_ROOT" ]] || { echo "New path already is Docker's data-root."; exit 0; }

case "$NEW_ROOT/" in "$CURRENT_ROOT/"*) die "new data-root must not be inside the current data-root" ;; esac
case "$CURRENT_ROOT/" in "$NEW_ROOT/"*) die "current data-root must not be inside the new data-root" ;; esac

if [[ -d $NEW_ROOT ]]; then
  [[ -r $NEW_ROOT && -w $NEW_ROOT ]] || die "destination is not readable/writable: $NEW_ROOT"
  DEST_ENTRY=$(find "$NEW_ROOT" -mindepth 1 -print -quit) \
    || die "could not inspect destination: $NEW_ROOT"
  [[ -z $DEST_ENTRY ]] || die "destination must be absent or empty: $NEW_ROOT"
fi

echo "Mode          : $([[ $ROOTLESS -eq 1 ]] && echo rootless || echo rootful)"
echo "Current data  : $CURRENT_ROOT"
echo "New data-root : $NEW_ROOT"
echo "Method        : $([[ $BIND_MOUNT -eq 1 ]] && echo bind-mount || echo daemon.json)"
echo "Dry run       : $([[ $DRY_RUN -eq 1 ]] && echo yes || echo no)"
echo "Delete old    : $([[ $DELETE_OLD -eq 1 ]] && echo yes || echo no)"

if (( DRY_RUN )); then
  echo "[DRY-RUN] would stop: ${SERVICE_UNITS[*]}"
  echo "[DRY-RUN] rsync -aHAX --numeric-ids --delete '$CURRENT_ROOT/' '$NEW_ROOT/'"
  if [[ -d $NEW_ROOT ]]; then
    rsync -aHAXn --numeric-ids --delete --itemize-changes "$CURRENT_ROOT/" "$NEW_ROOT/"
  else
    echo "[DRY-RUN] destination is absent; rsync comparison skipped to avoid creating it"
  fi
  echo "[DRY-RUN] would verify file count, logical bytes, a no-change rsync, service restart, and DockerRootDir"
  exit 0
fi

require_cmd find
require_cmd mktemp
if (( BIND_MOUNT )); then
  require_cmd findmnt
  require_cmd mountpoint
else
  require_cmd jq
fi

ACTIVE_UNITS=()
CONFIG_BACKUP=
CONFIG_EXISTED=0
CONFIG_TOUCHED=0
FSTAB_BACKUP=
OLD_BACKUP=
BIND_ACTIVE=0
COMMITTED=0

restart_docker() {
  if (( ROOTLESS )); then
    "${SERVICE_CTL[@]}" start docker.service
  else
    "${SERVICE_CTL[@]}" start containerd.service
    "${SERVICE_CTL[@]}" start docker.service
  fi
}

rollback() {
  local status=$?
  if (( status == 0 || COMMITTED == 1 )); then
    return
  fi
  trap - EXIT
  echo "Migration failed; rolling back configuration and the original data-root." >&2
  if (( BIND_ACTIVE )); then
    umount "$CURRENT_ROOT" || true
  fi
  if [[ -n $FSTAB_BACKUP && -f $FSTAB_BACKUP ]]; then
    cp -a -- "$FSTAB_BACKUP" /etc/fstab || true
  fi
  if [[ -n $OLD_BACKUP && -d $OLD_BACKUP ]]; then
    rmdir "$CURRENT_ROOT" 2>/dev/null || true
    mv -- "$OLD_BACKUP" "$CURRENT_ROOT" || true
  fi
  if (( CONFIG_TOUCHED )); then
    if (( CONFIG_EXISTED )); then
      cp -a -- "$CONFIG_BACKUP" "$DAEMON_JSON" || true
    else
      rm -f -- "$DAEMON_JSON"
    fi
  fi
  restart_docker || true
  exit "$status"
}
trap rollback EXIT

for unit in "${SERVICE_UNITS[@]}"; do
  if "${SERVICE_CTL[@]}" is-active --quiet "$unit"; then
    ACTIVE_UNITS+=("$unit")
  fi
done
for unit in "${ACTIVE_UNITS[@]}"; do
  "${SERVICE_CTL[@]}" stop "$unit"
done

if (( ROOTLESS )); then
  ! pgrep -u "$(id -u)" -x dockerd >/dev/null 2>&1 || die "rootless dockerd is still running"
else
  ! pgrep -u 0 -x dockerd >/dev/null 2>&1 || die "root dockerd is still running"
fi

install -d -m 0711 -- "$NEW_ROOT"
rsync -aHAX --numeric-ids --delete --info=progress2 "$CURRENT_ROOT/" "$NEW_ROOT/"

SOURCE_FILES=$(find "$CURRENT_ROOT" -xdev -type f -printf '.' | wc -c)
DEST_FILES=$(find "$NEW_ROOT" -xdev -type f -printf '.' | wc -c)
SOURCE_BYTES=$(find "$CURRENT_ROOT" -xdev -type f -printf '%s\n' | awk '{s+=$1} END{print s+0}')
DEST_BYTES=$(find "$NEW_ROOT" -xdev -type f -printf '%s\n' | awk '{s+=$1} END{print s+0}')
[[ $SOURCE_FILES = "$DEST_FILES" && $SOURCE_BYTES = "$DEST_BYTES" ]] \
  || die "copy count/byte verification failed (files $SOURCE_FILES/$DEST_FILES, bytes $SOURCE_BYTES/$DEST_BYTES)"
RSYNC_DIFF=$(rsync -aHAXn --numeric-ids --delete --itemize-changes "$CURRENT_ROOT/" "$NEW_ROOT/")
[[ -z $RSYNC_DIFF ]] || { printf '%s\n' "$RSYNC_DIFF" >&2; die "post-copy rsync verification found differences"; }

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
if (( BIND_MOUNT )); then
  require_cmd mountpoint
  FSTAB_BACKUP="/etc/fstab.pcprep.$timestamp.bak"
  cp -a -- /etc/fstab "$FSTAB_BACKUP"
  OLD_BACKUP="${CURRENT_ROOT}.pcprep.$timestamp.bak"
  [[ ! -e $OLD_BACKUP ]] || die "backup path already exists: $OLD_BACKUP"
  mv -- "$CURRENT_ROOT" "$OLD_BACKUP"
  install -d -m 0711 -- "$CURRENT_ROOT"
  mount --bind "$NEW_ROOT" "$CURRENT_ROOT"
  BIND_ACTIVE=1
  mountpoint -q "$CURRENT_ROOT" || die "bind mount verification failed"

  fstab_tmp=$(mktemp /etc/fstab.pcprep.XXXXXX)
  awk -v marker="# pcprep-docker-data-root" '
    skip { skip=0; next }
    $0 == marker { skip=1; next }
    { print }
  ' /etc/fstab > "$fstab_tmp"
  printf '%s\n%s %s none bind 0 0\n' \
    '# pcprep-docker-data-root' "$NEW_ROOT" "$CURRENT_ROOT" >> "$fstab_tmp"
  findmnt --verify --tab-file "$fstab_tmp" >/dev/null
  install -m 0644 "$fstab_tmp" /etc/fstab
  rm -f -- "$fstab_tmp"
  EXPECTED_ROOT=$CURRENT_ROOT
else
  install -d -m 0755 -- "$DOCKER_CFG_DIR"
  if [[ -f $DAEMON_JSON ]]; then
    CONFIG_EXISTED=1
    CONFIG_BACKUP="${DAEMON_JSON}.pcprep.$timestamp.bak"
    cp -a -- "$DAEMON_JSON" "$CONFIG_BACKUP"
    config_tmp=$(mktemp "$DOCKER_CFG_DIR/.daemon.json.XXXXXX")
    jq --arg root "$NEW_ROOT" '. + {"data-root": $root}' "$DAEMON_JSON" > "$config_tmp"
  else
    config_tmp=$(mktemp "$DOCKER_CFG_DIR/.daemon.json.XXXXXX")
    jq -n --arg root "$NEW_ROOT" '{"data-root": $root}' > "$config_tmp"
  fi
  jq empty "$config_tmp"
  chmod 0644 "$config_tmp"
  CONFIG_TOUCHED=1
  mv -f -- "$config_tmp" "$DAEMON_JSON"
  EXPECTED_ROOT=$NEW_ROOT
fi

restart_docker
NEW_SET_ROOT=
for _ in $(seq 1 30); do
  NEW_SET_ROOT=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || true)
  [[ -n $NEW_SET_ROOT ]] && break
  sleep 1
done
[[ -n $NEW_SET_ROOT ]] || die "Docker did not become ready after migration"
NEW_SET_ROOT=$(realpath -m -- "$NEW_SET_ROOT")
[[ $NEW_SET_ROOT = "$EXPECTED_ROOT" ]] \
  || die "DockerRootDir verification failed: expected $EXPECTED_ROOT, got $NEW_SET_ROOT"

COMMITTED=1
trap - EXIT

if (( BIND_MOUNT )); then
  if (( DELETE_OLD )); then
    [[ $OLD_BACKUP == "${CURRENT_ROOT}.pcprep."*.bak && $OLD_BACKUP != / ]] \
      || die "refusing unsafe backup deletion target: $OLD_BACKUP"
    rm -rf --one-file-system -- "$OLD_BACKUP"
    echo "Verified old store deleted: $OLD_BACKUP"
  else
    echo "Verified old store retained at: $OLD_BACKUP"
  fi
elif (( DELETE_OLD )); then
  OLD_BACKUP="${CURRENT_ROOT}.pcprep.$timestamp.bak"
  mv -- "$CURRENT_ROOT" "$OLD_BACKUP"
  [[ $OLD_BACKUP == "${CURRENT_ROOT}.pcprep."*.bak && $OLD_BACKUP != / ]] \
    || die "refusing unsafe backup deletion target: $OLD_BACKUP"
  rm -rf --one-file-system -- "$OLD_BACKUP"
  echo "Verified old store deleted: $OLD_BACKUP"
else
  echo "Verified old store retained at: $CURRENT_ROOT"
fi

echo "Docker data-root migration verified: $NEW_SET_ROOT"
