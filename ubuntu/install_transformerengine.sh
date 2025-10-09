#!/usr/bin/env bash
# install_cuda12_8_stack_safe.sh
# Ubuntu 24.04: Fix CUDA repo signing, install CUDA 12.8 toolkit (no driver),
# add env helper, install NCCL; optionally install cuDNN to the current conda env.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash $0" >&2
  exit 1
fi
. /etc/os-release
if [[ "${VERSION_CODENAME:-}" != "noble" ]]; then
  echo "This script targets Ubuntu 24.04 (noble). Detected: ${PRETTY_NAME:-unknown}." >&2
  exit 1
fi

DISTRO=ubuntu2404
CUDA_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/x86_64/"
KEY_DST="/etc/apt/keyrings/nvidia-cuda-${DISTRO}.gpg"
LIST_DST="/etc/apt/sources.list.d/cuda-${DISTRO}.list"

echo "==> 1) Clean up ONLY CUDA list.d entries (do not touch /etc/apt/sources.list)"
mkdir -p /etc/apt/sources.list.d/disabled
grep -Rl "developer.download.nvidia.com/compute/cuda/repos" /etc/apt/sources.list.d 2>/dev/null \
  | while read -r f; do
      echo "   - Disabling $f"
      mv -f "$f" "/etc/apt/sources.list.d/disabled/$(basename "$f").$(date +%s).disabled" || true
    done

echo "==> 2) Install CUDA repo key (DEARMORED) into /etc/apt/keyrings"
install -d -m 0755 /etc/apt/keyrings
tmpkey="$(mktemp)"
curl -fsSL "${CUDA_URL}3bf863cc.pub" -o "$tmpkey"
gpg --dearmor < "$tmpkey" > "$KEY_DST"
chmod 0644 "$KEY_DST"
rm -f "$tmpkey"

echo "==> 3) Create a single canonical CUDA sources.list.d file with signed-by"
cat > "$LIST_DST" <<EOF
deb [signed-by=${KEY_DST}] ${CUDA_URL} /
EOF
chmod 0644 "$LIST_DST"

echo "==> 4) apt-get update"
apt-get update

echo "==> 5) Install CUDA Toolkit 12.8 ONLY (no driver)"
DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-toolkit-12-8

echo "==> 6) Post-install sanity for nvcc"
/usr/local/cuda-12.8/bin/nvcc --version || { echo "nvcc missing?"; exit 2; }

echo "==> 7) Install NCCL headers+libs from CUDA repo"
DEBIAN_FRONTEND=noninteractive apt-get install -y libnccl2 libnccl-dev
test -f /usr/include/nccl.h && ls -l /usr/include/nccl.h
ls -l /usr/lib/x86_64-linux-gnu/libnccl.so* || true

echo "==> 8) Add per-shell switcher for CUDA 12.8"
cat > /usr/local/bin/use-cuda12.8 <<'EOS'
#!/usr/bin/env bash
export CUDA_HOME=/usr/local/cuda-12.8
export PATH="$CUDA_HOME/bin:${PATH}"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH}"
echo "Using CUDA at $CUDA_HOME"
nvcc --version 2>/dev/null || true
EOS
chmod +x /usr/local/bin/use-cuda12.8

echo "==> 9) (Optional) Detect conda and install cuDNN into current conda env"
if command -v conda >/dev/null 2>&1; then
  conda install -y nvidia::cudnn cuda-version=12
else
  echo "Conda not detected. If you want cuDNN in a conda env, install Miniconda first."
fi

echo "==> Done."
echo "Use per-shell:  source /usr/local/bin/use-cuda12.8"
echo "Driver note: This script never installs/changes the NVIDIA *driver*."


# finally install TransformerEngine
pip3 install --no-build-isolation transformer_engine[pytorch]