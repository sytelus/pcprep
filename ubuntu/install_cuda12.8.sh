#!/usr/bin/env bash
# install_cuda12_8_ubuntu24.04_only.sh
#
# Purpose:
#   - Ubuntu 24.04 (Noble) ONLY
#   - Fix NVIDIA CUDA repo signing (proper dearmored keyring in /etc/apt/keyrings)
#   - Create exactly ONE CUDA repo list file in /etc/apt/sources.list.d
#   - Install CUDA Toolkit 12.8 ONLY (NO driver packages)
#   - Leave existing nvidia-driver-* packages untouched
#   - Provide a per-shell helper to switch to CUDA 12.8
#
# Usage:
#   sudo bash install_cuda12_8_ubuntu24.04_only.sh
#
# Notes:
#   - This script will NOT install or modify the NVIDIA driver.
#   - It does NOT touch /etc/apt/sources.list (only manages files under sources.list.d).
#   - Safe to run multiple times (idempotent).

set -euo pipefail

# --- Guardrails ---------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash $0" >&2
  exit 1
fi

if ! grep -qE '^VERSION_CODENAME=noble$' /etc/os-release; then
  echo "This script is intended for Ubuntu 24.04 (Noble) only." >&2
  . /etc/os-release || true
  echo "Detected: ${PRETTY_NAME:-unknown}" >&2
  exit 1
fi

# --- Vars ---------------------------------------------------------------------
DISTRO=ubuntu2404
CUDA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/x86_64/"
CUDA_KEY_ARMOR_URL="${CUDA_REPO_URL}3bf863cc.pub"   # ASCII-armored public key
KEYRING_DIR="/etc/apt/keyrings"
KEY_DST="${KEYRING_DIR}/nvidia-cuda-${DISTRO}.gpg"  # dearmored keyring file
LIST_DST="/etc/apt/sources.list.d/cuda-${DISTRO}.list"
CUDA_META="cuda-toolkit-12-8"

# --- 1) Cleanup ONLY prior CUDA entries under sources.list.d ------------------
echo "==> Disabling any previous CUDA entries in /etc/apt/sources.list.d (if present)"
mkdir -p /etc/apt/sources.list.d/disabled
grep -Rl "developer.download.nvidia.com/compute/cuda/repos" /etc/apt/sources.list.d 2>/dev/null \
  | while read -r f; do
      ts="$(date +%s)"
      echo "   - Moving ${f} -> /etc/apt/sources.list.d/disabled/$(basename "$f").${ts}.disabled"
      mv -f "$f" "/etc/apt/sources.list.d/disabled/$(basename "$f").${ts}.disabled" || true
    done

# --- 2) Install dearmored repo key into /etc/apt/keyrings ---------------------
echo "==> Installing NVIDIA CUDA repo key (dearmored) into ${KEYRING_DIR}"
install -d -m 0755 "${KEYRING_DIR}"
tmpkey="$(mktemp)"
curl -fsSL "${CUDA_KEY_ARMOR_URL}" -o "${tmpkey}"
# dearmor to proper keyring file
gpg --dearmor < "${tmpkey}" > "${KEY_DST}"
chmod 0644 "${KEY_DST}"
rm -f "${tmpkey}"

# --- 3) Create a single canonical CUDA sources.list.d file --------------------
echo "==> Creating ${LIST_DST} with signed-by=${KEY_DST}"
cat > "${LIST_DST}" <<EOF
deb [signed-by=${KEY_DST}] ${CUDA_REPO_URL} /
EOF
chmod 0644 "${LIST_DST}"

# --- 4) Update apt ------------------------------------------------------------
echo "==> apt-get update"
apt-get update

# --- 5) Install CUDA Toolkit 12.8 ONLY (no driver) ---------------------------
echo "==> Installing ${CUDA_META} (toolkit only; driver untouched)"
DEBIAN_FRONTEND=noninteractive apt-get install -y "${CUDA_META}"

# --- 6) Sanity check ----------------------------------------------------------
if [[ -x /usr/local/cuda-12.8/bin/nvcc ]]; then
  echo "==> nvcc found at /usr/local/cuda-12.8/bin/nvcc:"
  /usr/local/cuda-12.8/bin/nvcc --version || true
else
  echo "ERROR: /usr/local/cuda-12.8/bin/nvcc not found after installation." >&2
  exit 2
fi

# --- 7) Add a per-shell env switcher (no global PATH changes) ----------------
echo "==> Installing per-shell helper: /usr/local/bin/use-cuda12.8"
cat > /usr/local/bin/use-cuda12.8 <<'EOS'
#!/usr/bin/env bash
# Per-shell switch to CUDA 12.8 (no system-wide changes)
export CUDA_HOME=/usr/local/cuda-12.8
export PATH="${CUDA_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"
echo "Using CUDA at ${CUDA_HOME}"
nvcc --version 2>/dev/null || true
EOS
chmod +x /usr/local/bin/use-cuda12.8

# --- 8) Final notes -----------------------------------------------------------
echo
echo "✅ CUDA Toolkit 12.8 installed (driver not modified)."
echo "To use it in your current shell:"
echo "  source /usr/local/bin/use-cuda12.8"
echo
echo "If you also need cuDNN or NCCL:"
echo "  - cuDNN (Conda env):   conda install -y nvidia::cudnn cuda-version=12"
echo "  - NCCL (system/apt):   sudo apt-get install -y libnccl2 libnccl-dev"
echo
echo "If 'apt update' ever complains about the CUDA repo signature again, just re-run this script."
