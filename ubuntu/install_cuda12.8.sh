#!/usr/bin/env bash
# install_cuda12_8_ubuntu24.04.sh
# Installs CUDA Toolkit 12.8 on Ubuntu 24.04 side-by-side with any other CUDA versions.
# Cleans duplicate/conflicting repo entries first. Does NOT touch your NVIDIA driver.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash $0"
  exit 1
fi

DISTRO=ubuntu2404
CUDA_META_PKG=cuda-toolkit-12-8
REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/x86_64/"
KEY_DST="/etc/apt/keyrings/nvidia-cuda-${DISTRO}.gpg"
LIST_DST="/etc/apt/sources.list.d/cuda-${DISTRO}.list"

echo "==> Step 0: Show/disable existing CUDA repo entries to avoid 'Signed-By' conflicts"
grep -R "developer.download.nvidia.com/compute/cuda/repos" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true

mkdir -p /etc/apt/sources.list.d/disabled
# Move any existing CUDA repo lines/files out of the way (idempotent)
grep -Rl "developer.download.nvidia.com/compute/cuda/repos" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null \
  | while read -r f; do
      echo "Disabling repo file: $f"
      bn="$(basename "$f")"
      mv -f "$f" "/etc/apt/sources.list.d/disabled/${bn}.$(date +%s).disabled" || true
    done

echo "==> Step 1: Install NVIDIA CUDA apt key (keyring) in /etc/apt/keyrings"
install -d -m 0755 /etc/apt/keyrings
# Official current key for CUDA repo (rotates occasionally)
curl -fsSL "${REPO_URL}3bf863cc.pub" -o "${KEY_DST}"
chmod 0644 "${KEY_DST}"

echo "==> Step 2: Create a single clean CUDA repo list file"
cat > "${LIST_DST}" <<EOF
deb [signed-by=${KEY_DST}] ${REPO_URL} /
EOF
chmod 0644 "${LIST_DST}"

echo "==> Step 3: Update apt and install CUDA Toolkit 12.8 (toolkit ONLY)"
apt-get update
# The meta-package installs toolkit to /usr/local/cuda-12.8 (won't touch driver)
DEBIAN_FRONTEND=noninteractive apt-get install -y "${CUDA_META_PKG}"

echo "==> Step 4: Post-install sanity"
if [[ -x /usr/local/cuda-12.8/bin/nvcc ]]; then
  echo "CUDA 12.8 installed at /usr/local/cuda-12.8"
  /usr/local/cuda-12.8/bin/nvcc --version || true
else
  echo "ERROR: nvcc not found under /usr/local/cuda-12.8/bin" >&2
  exit 2
fi

echo "==> Step 5 (optional): Create convenience switchers /usr/local/bin/use-cuda12.8 / use-cuda13.0"
cat > /usr/local/bin/use-cuda12.8 <<'EOS'
#!/usr/bin/env bash
export CUDA_HOME=/usr/local/cuda-12.8
export PATH="$CUDA_HOME/bin:${PATH}"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH}"
echo "Now using CUDA at $CUDA_HOME"
nvcc --version 2>/dev/null || true
EOS
chmod +x /usr/local/bin/use-cuda12.8

# Create a generic 'use-cudaX' helper if 13.0 exists; harmless if it doesn't
if [[ -d /usr/local/cuda-13.0 ]]; then
  cat > /usr/local/bin/use-cuda13.0 <<'EOS'
#!/usr/bin/env bash
export CUDA_HOME=/usr/local/cuda-13.0
export PATH="$CUDA_HOME/bin:${PATH}"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH}"
echo "Now using CUDA at $CUDA_HOME"
nvcc --version 2>/dev/null || true
EOS
  chmod +x /usr/local/bin/use-cuda13.0
fi

echo "==> Done. Use per-shell switching:"
echo "    source /usr/local/bin/use-cuda12.8"
[[ -d /usr/local/cuda-13.0 ]] && echo "    source /usr/local/bin/use-cuda13.0"
