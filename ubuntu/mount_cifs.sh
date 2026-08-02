#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage: mount_cifs.sh [--password-stdin] <mount-name> <//server/share> <username>

The password is read without echo by default. --password-stdin is intended for
a protected secret provider; passwords are never accepted as command arguments.
USAGE
}

PASSWORD_STDIN=0
if [[ ${1:-} == --password-stdin ]]; then PASSWORD_STDIN=1; shift; fi
[[ $# -eq 3 ]] || { usage; exit 2; }
MOUNT_NAME=$1
SHARE=$2
SMB_USER=$3

[[ $MOUNT_NAME =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Invalid mount name" >&2; exit 2; }
[[ $MOUNT_NAME != . && $MOUNT_NAME != .. ]] || { echo "Invalid mount name" >&2; exit 2; }
[[ $SHARE =~ ^//[^/[:space:]]+/[^[:space:]]+$ ]] || { echo "Share must be //server/share without whitespace" >&2; exit 2; }
[[ -n $SMB_USER && $SMB_USER != *$'\n'* && $SMB_USER != *$'\r'* ]] \
  || { echo "Invalid SMB username" >&2; exit 2; }

MOUNT_POINT="/mnt/$MOUNT_NAME"
for cmd in flock install mountpoint; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing $cmd" >&2; exit 1; }
done

sudo -v
LOCK_FILE=/run/lock/pcprep-mount-cifs.lock
sudo install -d -m 0755 /run/lock
sudo touch "$LOCK_FILE"
sudo chmod 0666 "$LOCK_FILE"
exec {CIFS_LOCK_FD}<>"$LOCK_FILE"
flock -n "$CIFS_LOCK_FD" \
  || { echo "Another pcprep CIFS update is in progress." >&2; exit 1; }
[[ ! -L $MOUNT_POINT && ( ! -e $MOUNT_POINT || -d $MOUNT_POINT ) ]] \
  || { echo "Mount point must be an ordinary directory: $MOUNT_POINT" >&2; exit 1; }
mountpoint -q "$MOUNT_POINT" \
  && { echo "Already mounted; unmount explicitly first: $MOUNT_POINT" >&2; exit 1; }

if (( PASSWORD_STDIN )); then
  IFS= read -r SMB_PASSWORD
else
  read -r -s -p "SMB password for $SMB_USER: " SMB_PASSWORD
  echo
fi
[[ -n $SMB_PASSWORD && $SMB_PASSWORD != *$'\n'* && $SMB_PASSWORD != *$'\r'* ]] \
  || { echo "Password must be non-empty and single-line" >&2; exit 2; }

if ! command -v mount.cifs >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y cifs-utils
fi
for cmd in findmnt mount; do command -v "$cmd" >/dev/null 2>&1 || { echo "Missing $cmd" >&2; exit 1; }; done

CRED_DIR=/etc/smbcredentials
CRED_FILE="$CRED_DIR/$MOUNT_NAME.cred"
MARKER="# pcprep-cifs:$MOUNT_NAME"
UID_NUM=$(id -u)
GID_NUM=$(id -g)
MOUNT_OPTIONS="nofail,_netdev,vers=3.0,credentials=$CRED_FILE,uid=$UID_NUM,gid=$GID_NUM,dir_mode=0750,file_mode=0640,serverino"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
FSTAB_BACKUP="/etc/fstab.pcprep.$STAMP.bak"
CRED_BACKUP=
COMMITTED=0
FSTAB_BACKUP_READY=0
CREDENTIAL_TOUCHED=0
MOUNT_STARTED=0
CRED_TMP=
FSTAB_TMP=

rollback() {
  local status=$?
  unset SMB_PASSWORD
  if (( status == 0 || COMMITTED == 1 )); then return; fi
  trap - EXIT
  echo "CIFS setup failed; restoring credentials and /etc/fstab." >&2
  [[ -z $CRED_TMP ]] || sudo rm -f -- "$CRED_TMP" 2>/dev/null || true
  [[ -z $FSTAB_TMP ]] || sudo rm -f -- "$FSTAB_TMP" 2>/dev/null || true
  if (( MOUNT_STARTED )); then
    mountpoint -q "$MOUNT_POINT" && sudo umount "$MOUNT_POINT" 2>/dev/null || true
  fi
  if (( FSTAB_BACKUP_READY )); then
    sudo cp -a -- "$FSTAB_BACKUP" /etc/fstab 2>/dev/null || true
  fi
  if (( CREDENTIAL_TOUCHED )); then
    if [[ -n $CRED_BACKUP ]]; then
      if sudo cp -a -- "$CRED_BACKUP" "$CRED_FILE" 2>/dev/null; then
        sudo rm -f -- "$CRED_BACKUP" 2>/dev/null || true
      fi
    else
      sudo rm -f -- "$CRED_FILE" 2>/dev/null || true
    fi
  fi
  exit "$status"
}
trap rollback EXIT

sudo install -d -m 0755 "$MOUNT_POINT"
sudo install -d -m 0700 "$CRED_DIR"
sudo cp -a -- /etc/fstab "$FSTAB_BACKUP"
FSTAB_BACKUP_READY=1
if sudo test -f "$CRED_FILE"; then
  CRED_BACKUP="${CRED_FILE}.pcprep.$STAMP.bak"
  sudo cp -a -- "$CRED_FILE" "$CRED_BACKUP"
fi

CRED_TMP=$(sudo mktemp "$CRED_DIR/.${MOUNT_NAME}.cred.XXXXXX")
printf 'username=%s\npassword=%s\n' "$SMB_USER" "$SMB_PASSWORD" | sudo tee "$CRED_TMP" >/dev/null
unset SMB_PASSWORD
sudo chmod 0600 "$CRED_TMP"
sudo chown root:root "$CRED_TMP"
CREDENTIAL_TOUCHED=1
sudo mv -f -- "$CRED_TMP" "$CRED_FILE"

FSTAB_TMP=$(sudo mktemp /etc/.fstab.pcprep.XXXXXX)
sudo awk -v marker="$MARKER" '
  skip { skip=0; next }
  $0 == marker { skip=1; next }
  { print }
' /etc/fstab | sudo tee "$FSTAB_TMP" >/dev/null
printf '%s\n%s %s cifs %s 0 0\n' "$MARKER" "$SHARE" "$MOUNT_POINT" "$MOUNT_OPTIONS" \
  | sudo tee -a "$FSTAB_TMP" >/dev/null
sudo findmnt --verify --tab-file "$FSTAB_TMP" >/dev/null
sudo chmod 0644 "$FSTAB_TMP"
sudo chown root:root "$FSTAB_TMP"
sudo mv -f -- "$FSTAB_TMP" /etc/fstab

MOUNT_STARTED=1
sudo mount "$MOUNT_POINT"
mountpoint -q "$MOUNT_POINT" || { echo "Mount verification failed" >&2; exit 1; }

if [[ -n $CRED_BACKUP ]]; then
  sudo rm -f -- "$CRED_BACKUP"
fi

COMMITTED=1
trap - EXIT
echo "Mounted $SHARE at $MOUNT_POINT; fstab backup: $FSTAB_BACKUP"
