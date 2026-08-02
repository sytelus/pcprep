#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "Run as root: sudo bash $0" >&2; exit 1; }
for cmd in apt-get awk cp curl gpg install mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

DISTRO=${CUDA_REPO_DISTRO:-ubuntu2404}
ARCH=${CUDA_REPO_ARCH:-x86_64}
[[ $DISTRO =~ ^[a-z0-9]+$ && $ARCH =~ ^[A-Za-z0-9_-]+$ ]] \
  || { echo "Invalid CUDA repository distro/architecture override" >&2; exit 2; }
REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/${ARCH}/"
KEY_URL="${REPO_URL}3bf863cc.pub"
KEY_DST="/etc/apt/keyrings/nvidia-cuda-${DISTRO}.gpg"
LIST_DST="/etc/apt/sources.list.d/cuda-${DISTRO}.list"
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP_DIR=$(mktemp -d "/var/backups/pcprep-cuda-repo-$STAMP.XXXXXX")
chmod 0700 "$BACKUP_DIR"

declare -a ORIGINALS=()
declare -a BACKUPS=()
declare -a TEMP_FILES=()
backup_file() {
  local source=$1 backup="$BACKUP_DIR${1}"
  install -d -m 0700 "$(dirname "$backup")"
  cp -a -- "$source" "$backup"
  ORIGINALS+=("$source")
  BACKUPS+=("$backup")
}

KEY_EXISTED=0
LIST_EXISTED=0
[[ -e $KEY_DST ]] && { KEY_EXISTED=1; backup_file "$KEY_DST"; }
[[ -e $LIST_DST ]] && { LIST_EXISTED=1; backup_file "$LIST_DST"; }
COMMITTED=0
rollback() {
  local status=$?
  if (( status == 0 || COMMITTED == 1 )); then return; fi
  trap - EXIT
  echo "CUDA repository update failed; restoring all changed apt files." >&2
  local i
  for temporary in "${TEMP_FILES[@]}"; do
    rm -f -- "$temporary" 2>/dev/null || true
  done
  for ((i=0; i<${#ORIGINALS[@]}; i++)); do
    cp -a -- "${BACKUPS[$i]}" "${ORIGINALS[$i]}" || true
  done
  (( KEY_EXISTED )) || rm -f -- "$KEY_DST"
  (( LIST_EXISTED )) || rm -f -- "$LIST_DST"
  exit "$status"
}
trap rollback EXIT

mapfile -t source_files < <(
  {
    [[ -f /etc/apt/sources.list ]] && printf '%s\n' /etc/apt/sources.list
    find /etc/apt/sources.list.d -maxdepth 1 -type f \( -name '*.list' -o -name '*.sources' \) -print 2>/dev/null
  } | sort -u
)

for source_file in "${source_files[@]}"; do
  [[ $source_file != "$LIST_DST" ]] || continue
  grep -q 'developer.download.nvidia.com/compute/cuda/repos' "$source_file" || continue
  backup_file "$source_file"
  edited=$(mktemp "$(dirname "$source_file")/.pcprep-cuda-source.XXXXXX")
  TEMP_FILES+=("$edited")
  if [[ $source_file == *.sources ]]; then
    awk -v RS='' -v ORS='\n\n' \
      '$0 !~ /developer\.download\.nvidia\.com\/compute\/cuda\/repos/' \
      "$source_file" > "$edited"
  else
    awk '!/developer\.download\.nvidia\.com\/compute\/cuda\/repos/' \
      "$source_file" > "$edited"
  fi
  chmod --reference="$source_file" "$edited"
  chown --reference="$source_file" "$edited"
  mv -f -- "$edited" "$source_file"
  echo "Removed only CUDA entries from $source_file"
done

install -d -m 0755 /etc/apt/keyrings
tmp_key=$(mktemp)
tmp_ring=$(mktemp)
TEMP_FILES+=("$tmp_key" "$tmp_ring")
rm -f -- "$tmp_ring"
curl -fsSL "$KEY_URL" -o "$tmp_key"
gpg --batch --dearmor --output "$tmp_ring" "$tmp_key"
gpg --batch --with-colons --show-keys "$tmp_ring" | grep -qi 'A4B469963BF863CC' \
  || { echo "Downloaded key does not contain expected NVIDIA fingerprint" >&2; exit 1; }
install -m 0644 "$tmp_ring" "$KEY_DST"
rm -f -- "$tmp_key" "$tmp_ring"

list_tmp=$(mktemp)
TEMP_FILES+=("$list_tmp")
printf 'deb [signed-by=%s] %s /\n' "$KEY_DST" "$REPO_URL" > "$list_tmp"
install -m 0644 "$list_tmp" "$LIST_DST"
rm -f -- "$list_tmp"

apt-get update
COMMITTED=1
trap - EXIT
echo "CUDA apt repository repaired. Backups retained at $BACKUP_DIR"
