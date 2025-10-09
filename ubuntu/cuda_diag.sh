#!/usr/bin/env bash
set -euo pipefail
echo "== PATH (conda may be active) =="
echo "$PATH"
echo "== Check nvidia-smi in clean env =="
if env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin /usr/bin/which nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi FOUND in /usr/bin"
  echo "Running nvidia-smi (clean env):"
  env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin /usr/bin/nvidia-smi || true
else
  echo "nvidia-smi NOT FOUND -> install NVIDIA driver (ubuntu-drivers autoinstall)."
fi
echo "== DKMS status (driver build) =="
command -v dkms >/dev/null && dkms status || echo "dkms not installed"
echo "== CUDA toolkits present =="
ls -d /usr/local/cuda-* 2>/dev/null || true
echo "== nvcc versions (if any) =="
for c in /usr/local/cuda-*/bin/nvcc; do echo -n "$c -> "; "$c" --version | sed -n '1,2p'; done 2>/dev/null || true

