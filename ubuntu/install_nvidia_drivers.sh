#!/usr/bin/env bash
# install_nvidia_driver_580_only_ubuntu24.04.sh
# Ubuntu 24.04 only. Installs a 580-series NVIDIA driver (and nothing else).
# Fails if:
#   - No 580 driver package is available in your enabled repositories, OR
#   - A non-580 NVIDIA driver is already installed and couldn't be removed.
#
# It will:
#   1) Ensure required build tools/headers are present
#   2) Refuse to proceed if *any* non-580 NVIDIA driver is installed
#   3) Choose the best available 580 package (priority order below) and install it
#   4) Reboot to load the driver

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

if ! grep -q "Ubuntu 24\.04" /etc/os-release; then
  echo "This script is intended for Ubuntu 24.04 only." >&2
  exit 1
fi

echo "==> Step 0: Pre-reqs"
apt-get update
apt-get install -y \
  ubuntu-drivers-common linux-headers-$(uname -r) dkms build-essential \
  mokutil pciutils

echo "==> Step 1: Refuse if a non-580 NVIDIA driver is already installed"
# List installed packages that look like nvidia-driver-* (desktop/server/open)
INSTALLED_PKGS=$(dpkg-query -W -f='${Package} ${Status}\n' 'nvidia-driver-*' 2>/dev/null | awk '$2=="install" && $3=="ok" && $4=="installed"{print $1}' || true)

if [[ -n "${INSTALLED_PKGS}" ]]; then
  NON_580=$(echo "${INSTALLED_PKGS}" | grep -Ev '^(nvidia-driver-580(-open|-server|-server-open)?)$' || true)
  if [[ -n "${NON_580}" ]]; then
    echo "Found NON-580 NVIDIA driver(s) installed:" >&2
    echo "${NON_580}" >&2
    echo "Refusing to continue. Please remove/purge them first, then rerun this script." >&2
    echo "Example:" >&2
    echo "  sudo apt-get purge -y ${NON_580}" >&2
    exit 2
  fi
fi

echo "==> Step 2: Discover 580-series packages available in your repos"
# Strictly 580 only (desktop first, then open variant, then server variants)
CANDIDATES_ORDER=(
  nvidia-driver-580
  nvidia-driver-580-open
  nvidia-driver-580-server
  nvidia-driver-580-server-open
)

AVAILABLE_580=()
for pkg in "${CANDIDATES_ORDER[@]}"; do
  cand_ver=$(apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/{print $2}')
  if [[ -n "${cand_ver}" && "${cand_ver}" != "(none)" ]]; then
    AVAILABLE_580+=("$pkg")
  fi
done

if [[ ${#AVAILABLE_580[@]} -eq 0 ]]; then
  echo "ERROR: No 580-series NVIDIA driver packages are available in your enabled repositories." >&2
  echo "Tip: enable the appropriate repository (e.g., Ubuntu restricted updates/security or NVIDIA CUDA repo/graphics-drivers PPA) and rerun." >&2
  echo "Current candidates (for debugging):"
  apt-cache policy 'nvidia-driver-*' | sed -n '1,200p' >&2 || true
  exit 3
fi

# Choose the first (highest priority) 580 package that is available
PKG="${AVAILABLE_580[0]}"
echo "==> Will install strictly 580-series driver: ${PKG}"

echo "==> Step 3: Install ${PKG}"
apt-get install -y "${PKG}"

echo "==> Step 4: Verify no non-580 drivers slipped in as dependencies"
POST_INSTALL_PKGS=$(dpkg-query -W -f='${Package} ${Status}\n' 'nvidia-driver-*' 2>/dev/null | awk '$2=="install" && $3=="ok" && $4=="installed"{print $1}' || true)
BAD_AFTER_INSTALL=$(echo "${POST_INSTALL_PKGS}" | grep -Ev '^(nvidia-driver-580(-open|-server|-server-open)?)$' || true)
if [[ -n "${BAD_AFTER_INSTALL}" ]]; then
  echo "ERROR: Non-580 driver(s) ended up installed unexpectedly:" >&2
  echo "${BAD_AFTER_INSTALL}" >&2
  echo "Aborting to honor the '580-only' constraint. You can purge them and rerun." >&2
  exit 4
fi

echo "==> Step 5: Secure Boot check"
if mokutil --sb-state 2>/dev/null | grep -qi enabled; then
  echo "Secure Boot is ENABLED. On reboot you may need to enroll a MOK so the NVIDIA kernel module can load."
fi

echo "==> Step 6: Rebooting to load the driver..."
reboot
