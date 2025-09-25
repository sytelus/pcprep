#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  docker-move-data.sh <NEW_DATA_ROOT> [--rootless] [--dry-run] [--bind-mount] [--delete-old]

Description:
  Moves Docker's data-root (images, containers, volumes, Buildx cache) to a new location.
  - Rootful (default): edits /etc/docker/daemon.json and restarts system services.
  - Rootless (--rootless): edits ~/.config/docker/daemon.json and restarts user services.
  - --dry-run: rsync trial run, no changes.
  - --bind-mount: alternative method (move /var/lib/docker to NEW_DATA_ROOT and bind-mount it back).
  - --delete-old: delete old directory after successful move (otherwise it's kept as .bak).

Notes:
  - Requires rsync. jq is optional (used to safely edit daemon.json if present).
  - For rootful mode, run as root (sudo). For rootless, DO NOT use sudo.
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Error: required command '$1' not found."; exit 1; }
}

# --- Parse args
if [[ $# -lt 1 ]]; then usage; exit 1; fi
NEW_ROOT="$1"; shift || true
ROOTLESS=0
DRYRUN=0
BINDMOUNT=0
DELETE_OLD=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rootless) ROOTLESS=1 ;;
    --dry-run) DRYRUN=1 ;;
    --bind-mount) BINDMOUNT=1 ;;
    --delete-old) DELETE_OLD=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
  shift
done

require_cmd rsync
# docker may not be running yet; info is optional, but we'll try to probe
if command -v docker >/dev/null 2>&1; then
  :
else
  echo "Warning: 'docker' not found in PATH. Proceeding with filesystem operations only."
fi

# --- Determine current data-root and mode
if (( ROOTLESS )); then
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    echo "Error: --rootless must NOT be run as root. Re-run without sudo." >&2
    exit 1
  fi
  DOCKER_CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/docker"
  DAEMON_JSON="${DOCKER_CFG_DIR}/daemon.json"
  CURRENT_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/docker"
  SERVICE_CTRL="systemctl --user"
  SOCKET_NAME="docker.socket"
  SERVICE_NAME="docker.service"
else
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Error: rootful mode requires sudo/root. Re-run as: sudo $0 $NEW_ROOT" >&2
    exit 1
  fi
  DOCKER_CFG_DIR="/etc/docker"
  DAEMON_JSON="${DOCKER_CFG_DIR}/daemon.json"
  CURRENT_ROOT="/var/lib/docker"
  SERVICE_CTRL="systemctl"
  SOCKET_NAME="docker.socket"
  SERVICE_NAME="docker"
fi

# If docker exists, try to read actual data-root (overrides defaults)
if command -v docker >/dev/null 2>&1; then
  set +e
  PROBED_ROOT="$(docker info 2>/dev/null | sed -n 's/ *Docker Root Dir: //p')"
  set -e
  if [[ -n "${PROBED_ROOT:-}" ]]; then
    CURRENT_ROOT="$PROBED_ROOT"
  fi
fi

# --- Preflight
echo "Mode           : $([[ $ROOTLESS -eq 1 ]] && echo rootless || echo rootful)"
echo "Current data   : ${CURRENT_ROOT}"
echo "New data-root  : ${NEW_ROOT}"
echo "Method         : $([[ $BINDMOUNT -eq 1 ]] && echo bind-mount || echo daemon.json data-root)"
echo "Dry run        : $([[ $DRYRUN -eq 1 ]] && echo yes || echo no)"
echo "Delete old     : $([[ $DELETE_OLD -eq 1 ]] && echo yes || echo no)"
echo

if [[ "${CURRENT_ROOT%/}" == "${NEW_ROOT%/}" ]]; then
  echo "New path equals current data-root. Nothing to do."
  exit 0
fi

# Create destination
mkdir -p "${NEW_ROOT}"
chmod 711 "${NEW_ROOT}" || true

# --- Stop Docker
echo "Stopping Docker services..."
set +e
$SERVICE_CTRL stop "$SERVICE_NAME" >/dev/null 2>&1
$SERVICE_CTRL stop "$SOCKET_NAME" >/dev/null 2>&1
# containerd for rootful
if (( ! ROOTLESS )); then $SERVICE_CTRL stop containerd >/dev/null 2>&1; fi
set -e

# --- Choose strategy
if (( BINDMOUNT )); then
  # Move the whole directory and bind-mount it back to CURRENT_ROOT
  echo "Moving ${CURRENT_ROOT} -> ${NEW_ROOT}"
  if (( DRYRUN )); then
    echo "[DRY-RUN] rsync -aHAX ${CURRENT_ROOT}/ ${NEW_ROOT}/"
  else
    # Preserve attributes & hardlinks
    rsync -aHAX --info=progress2 "${CURRENT_ROOT}/" "${NEW_ROOT}/"
    mv "${CURRENT_ROOT}" "${CURRENT_ROOT}.bak.$(date +%s)"
    mkdir -p "${CURRENT_ROOT}"
    mount --bind "${NEW_ROOT}" "${CURRENT_ROOT}"
    # Persist bind mount in fstab
    if (( ROOTLESS )); then
      FSTAB="$HOME/.config/fstab"
      mkdir -p "$(dirname "$FSTAB")"
    else
      FSTAB="/etc/fstab"
    fi
    echo "${NEW_ROOT}  ${CURRENT_ROOT}  none  bind  0  0" | sudo tee -a "$FSTAB" >/dev/null
  fi
else
  # rsync + daemon.json data-root change
  echo "Syncing data ${CURRENT_ROOT} -> ${NEW_ROOT}"
  RSYNC_OPTS="-aHAX --info=progress2"
  (( DRYRUN )) && RSYNC_OPTS="--dry-run ${RSYNC_OPTS}"
  rsync ${RSYNC_OPTS} "${CURRENT_ROOT}/" "${NEW_ROOT}/"

  # Update daemon.json
  echo "Configuring data-root in ${DAEMON_JSON}"
  mkdir -p "${DOCKER_CFG_DIR}"
  if command -v jq >/dev/null 2>&1; then
    if [[ -s "${DAEMON_JSON}" ]]; then
      tmp="$(mktemp)"; cp -a "${DAEMON_JSON}" "$tmp"
      jq --arg newroot "${NEW_ROOT}" '. + { "data-root": $newroot }' "$tmp" > "${DAEMON_JSON}.new"
      mv "${DAEMON_JSON}.new" "${DAEMON_JSON}"
    else
      printf '{\n  "data-root": "%s"\n}\n' "${NEW_ROOT}" > "${DAEMON_JSON}"
    fi
  else
    echo "Warning: 'jq' not found; writing minimal daemon.json (existing settings not merged)."
    printf '{\n  "data-root": "%s"\n}\n' "${NEW_ROOT}" > "${DAEMON_JSON}"
  fi
fi

# --- Start Docker
echo "Starting Docker services..."
set +e
if (( ! ROOTLESS )); then $SERVICE_CTRL start containerd >/dev/null 2>&1; fi
$SERVICE_CTRL start "$SOCKET_NAME" >/dev/null 2>&1
$SERVICE_CTRL start "$SERVICE_NAME" >/dev/null 2>&1
set -e

# --- Verify
if command -v docker >/dev/null 2>&1; then
  sleep 1
  NEW_SET_ROOT="$(docker info 2>/dev/null | sed -n 's/ *Docker Root Dir: //p')"
  echo "Docker Root Dir now: ${NEW_SET_ROOT:-<unknown>}"
  if [[ -n "${NEW_SET_ROOT:-}" && "${NEW_SET_ROOT%/}" != "${NEW_ROOT%/}" ]]; then
    echo "ERROR: Docker is not using the new data-root. Check ${DAEMON_JSON} and logs: 'journalctl -u ${SERVICE_NAME}'."
    exit 1
  fi
else
  echo "docker not found; skipping runtime verification."
fi

# --- Cleanup old
if (( ! DRYRUN )); then
  if (( DELETE_OLD )); then
    if (( BINDMOUNT )); then
      # In bind-mount mode we left a .bak; delete it
      OLD_BAK="$(ls -1d ${CURRENT_ROOT}.bak.* 2>/dev/null | tail -n 1 || true)"
      if [[ -n "${OLD_BAK}" ]]; then
        echo "Deleting old backup: ${OLD_BAK}"
        rm -rf "${OLD_BAK}"
      fi
    else
      echo "Renaming old data dir for safety: ${CURRENT_ROOT} -> ${CURRENT_ROOT}.bak"
      mv "${CURRENT_ROOT}" "${CURRENT_ROOT}.bak" || true
      echo "Deleting old backup: ${CURRENT_ROOT}.bak"
      rm -rf "${CURRENT_ROOT}.bak"
    fi
  else
    echo "Keeping old data as backup. You can remove it later."
    if (( ! BINDMOUNT )); then
      [[ -d "${CURRENT_ROOT}" ]] && mv "${CURRENT_ROOT}" "${CURRENT_ROOT}.bak.$(date +%s)" || true
    fi
  fi
fi

echo "✅ Done."
echo "Tip: 'docker system df' to inspect usage; 'docker buildx ls' to confirm builders."
