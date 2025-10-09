#!/usr/bin/env bash
# fix_cuda_repo_key_ubuntu24.04.sh
# Fixes NO_PUBKEY for NVIDIA CUDA repo on Ubuntu 24.04 by:
# - Disabling duplicate/old CUDA repo entries
# - Installing the correct key into /etc/apt/keyrings
# - Creating a single signed-by repo line

set -euo pipefail
if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash $0"; exit 1
fi

DISTRO=ubuntu2404
REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/x86_64/"
KEY_DST="/etc/apt/keyrings/nvidia-cuda-${DISTRO}.gpg"
LIST_DST="/etc/apt/sources.list.d/cuda-${DISTRO}.list"

echo "==> Disable any existing CUDA repo files to avoid conflicts"
mkdir -p /etc/apt/sources.list.d/disabled
grep -Rl "developer.download.nvidia.com/compute/cuda/repos" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null \
  | while read -r f; do
      echo "Disabling $f"
      mv -f "$f" "/etc/apt/sources.list.d/disabled/$(basename "$f").$(date +%s).disabled" || true
    done

echo "==> Install CUDA repo key into /etc/apt/keyrings"
install -d -m 0755 /etc/apt/keyrings
# Key ID ends with 3BF863CC (matches the NO_PUBKEY message)
curl -fsSL "${REPO_URL}3bf863cc.pub" -o "${KEY_DST}"
chmod 0644 "${KEY_DST}"

echo "==> Create a single canonical repo file with signed-by"
cat > "${LIST_DST}" <<EOF
deb [signed-by=${KEY_DST}] ${REPO_URL} /
EOF
chmod 0644 "${LIST_DST}"

echo "==> apt-get update (should be clean now)"
apt-get update
echo "OK"
