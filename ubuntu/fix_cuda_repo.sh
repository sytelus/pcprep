#!/usr/bin/env bash
# fix_cuda_repo_signedby_ubuntu24.04.sh
# Fixes "E: ... InRelease is not signed / NO_PUBKEY A4B469963BF863CC" for CUDA repo on Ubuntu 24.04.
# - Removes/archives duplicate CUDA repo entries
# - Installs the proper NVIDIA CUDA repo key, *dearmored*, into /etc/apt/keyrings
# - Creates exactly one sources.list.d entry that uses signed-by=<that keyring>
# - Runs apt update and prints a concise status

set -euo pipefail
if [[ $EUID -ne 0 ]]; then echo "Run as root: sudo bash $0"; exit 1; fi

DISTRO=ubuntu2404
REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/x86_64/"
KEY_URL="${REPO_URL}3bf863cc.pub"     # Key whose short ID ends with 3BF863CC (matches the NO_PUBKEY)
KEY_DST="/etc/apt/keyrings/nvidia-cuda-${DISTRO}.gpg"  # dearmored keyring
LIST_DST="/etc/apt/sources.list.d/cuda-${DISTRO}.list"

echo "==> 1) Disable any existing CUDA repo entries to avoid conflicts"
mkdir -p /etc/apt/sources.list.d/disabled
# Move any lines/files that reference the CUDA repo (in both main list and list.d)
grep -Rl "developer.download.nvidia.com/compute/cuda/repos" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null \
  | while read -r f; do
      echo "    - Disabling $f"
      mv -f "$f" "/etc/apt/sources.list.d/disabled/$(basename "$f").$(date +%s).disabled" || true
    done

echo "==> 2) Install CUDA repo key into /etc/apt/keyrings (DEARMORED)"
install -d -m 0755 /etc/apt/keyrings
tmpkey="$(mktemp)"
curl -fsSL "$KEY_URL" -o "$tmpkey"
# Dearmor into a proper keyring file
gpg --dearmor < "$tmpkey" > "$KEY_DST"
chmod 0644 "$KEY_DST"
rm -f "$tmpkey"

echo "==> 3) Create single canonical repo file with signed-by=${KEY_DST}"
cat > "$LIST_DST" <<EOF
deb [signed-by=${KEY_DST}] ${REPO_URL} /
EOF
chmod 0644 "$LIST_DST"

echo "==> 4) Quick sanity: show the new repo line and key info"
echo "-- Repo file:"
cat "$LIST_DST"
echo "-- Key fingerprints (should include ...A4B469963BF863CC):"
gpg --show-keys "$KEY_DST" || true

echo "==> 5) apt-get update (should be clean now)"
apt-get update

echo "✅ CUDA repo fixed and trusted."
echo
echo "NOTE: You may still see warnings about other repos (e.g., Docker or PPAs) using legacy trusted.gpg."
echo "      Those are harmless for CUDA; you can migrate those keys later if you want."
