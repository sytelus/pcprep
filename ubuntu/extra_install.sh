#!/usr/bin/env bash
# Fail fast and be loud
set -euo pipefail

# Purpose: Install extra QoL and dev tools not covered by prepare_new_box.sh/min_system.sh
# Behavior:
# - Honors NO_NET=1 to skip any network-required installs
# - Skips sudo-requiring installs if passwordless sudo/root is unavailable
# - Skips packages not present in current APT repos (no extra repos added)
# - Skips select packages on WSL (not installable/useful there)
# - Supports architectures: x86_64/amd64, arm64/aarch64, armhf/armv7l

export DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-noninteractive}
NO_NET=${NO_NET:-}

log() { echo "[extra_install] $*"; }
warn() { echo "[extra_install][WARN] $*" >&2; }

# Detect architecture (uname) and translate to Debian arch
ARCH_UNAME=$(uname -m)
case "$ARCH_UNAME" in
  x86_64|amd64)
    ARCH_UNAME="x86_64"; ARCH_DEB="amd64" ;;
  aarch64|arm64)
    ARCH_UNAME="aarch64"; ARCH_DEB="arm64" ;;
  armv7l|armhf)
    ARCH_UNAME="armv7l"; ARCH_DEB="armhf" ;;
  *)
    warn "Unsupported architecture: $ARCH_UNAME. Some packages may be skipped."; ARCH_DEB="" ;;
esac

# Detect WSL
IS_WSL=0
if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=1
fi

# Sudo detection (passwordless) or root
HAS_SUDO=0
if [ "$(id -u)" = "0" ]; then
  HAS_SUDO=1
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  HAS_SUDO=1
fi

_sudo() {
  if [ "$HAS_SUDO" = "1" ]; then sudo "$@"; else "$@"; fi
}

require_install_perms() {
  if [ "$HAS_SUDO" != "1" ]; then
    warn "Sudo/root not available. Skipping installs that require elevated privileges."
    return 1
  fi
  if [ "${NO_NET:-0}" = "1" ]; then
    warn "NO_NET=1 set. Skipping network-dependent installations."
    return 1
  fi
  return 0
}

APT_UPDATED=0
apt_update_once() {
  if [ "$APT_UPDATED" = "0" ]; then
    _sudo apt-get update -y || true
    APT_UPDATED=1
  fi
}

# Check if a package exists in current repositories
apt_has_pkg() {
  local pkg="$1"
  if apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2}' | grep -vq "(none)"; then
    return 0
  fi
  return 1
}

# Install a single package if available; otherwise warn
install_pkg() {
  local pkg="$1"; shift || true
  if ! require_install_perms; then return 1; fi
  if ! apt_has_pkg "$pkg"; then
    warn "Package '$pkg' not available in current APT sources for arch '$ARCH_DEB'. Skipping."
    return 1
  fi
  apt_update_once
  log "Installing: $pkg"
  _sudo apt-get install -y --no-install-recommends "$pkg" || warn "Failed to install $pkg"
}

# Install the first available package from a preference list
install_first_available() {
  # usage: install_first_available pkgA [pkgB ...]
  local chosen=""
  for p in "$@"; do
    if apt_has_pkg "$p"; then chosen="$p"; break; fi
  done
  if [ -n "$chosen" ]; then install_pkg "$chosen"; else warn "None available: $*"; fi
}

# Skip helper with message
skip() { log "Skipping: $*"; }

log "Arch(uname)=$ARCH_UNAME, Arch(deb)=$ARCH_DEB, WSL=$IS_WSL, NO_NET=${NO_NET:-0}, HAS_SUDO=$HAS_SUDO"

# ----- Everyday CLI QoL -----
install_qol() {
  install_pkg ripgrep || true
  install_pkg fd-find || true
  install_pkg bat || true
  install_pkg fzf || true
  install_pkg tldr || true
  install_pkg tree || true

  # Prefer gdu if available, else ncdu
  if apt_has_pkg gdu; then install_pkg gdu; else install_pkg ncdu || true; fi

  install_pkg moreutils || true
  # 'rename' may be 'rename' (perl-rename) or 'renameutils' on some systems; prefer 'rename'
  if apt_has_pkg rename; then install_pkg rename; elif apt_has_pkg renameutils; then install_pkg renameutils; else warn "Neither 'rename' nor 'renameutils' available"; fi
  install_pkg jq || true
  # yq availability varies by Ubuntu release; skip if missing
  install_pkg yq || true
  install_pkg parallel || true
  install_pkg entr || true
  install_pkg rsync || true
}

# ----- Build & Toolchains -----
install_build_tools() {
  install_pkg pkg-config || true
  install_pkg ninja-build || true
  install_pkg meson || true
  install_pkg autoconf || true
  install_pkg automake || true
  install_pkg libtool || true
  install_pkg ccache || true
  install_pkg clang || true
  install_pkg clang-format || true
  install_pkg clang-tidy || true

  # Faster linkers: prefer mold if available, else lld
  if apt_has_pkg mold; then install_pkg mold; elif apt_has_pkg lld; then install_pkg lld; else warn "No fast linker (mold/lld) available for $ARCH_DEB"; fi

  install_pkg gdb || true
  install_pkg lldb || true

  # Valgrind: may be unavailable on some arches
  if [ "$ARCH_DEB" = "armhf" ]; then
    # valgrind support on armhf can be limited on some releases
    if apt_has_pkg valgrind; then install_pkg valgrind; else skip "valgrind not available for armhf on this distro"; fi
  else
    install_pkg valgrind || true
  fi

  install_pkg strace || true
  install_pkg ltrace || true

  # Common dev headers
  install_pkg libssl-dev || true
  install_pkg libffi-dev || true
  install_pkg libbz2-dev || true
  install_pkg liblzma-dev || true
  install_pkg libsqlite3-dev || true
}

# ----- System / Perf / HW -----
install_system_hw() {
  # Prefer modern btop; else glances
  if apt_has_pkg btop; then install_pkg btop; else install_pkg glances || true; fi
  install_pkg sysstat || true
  install_pkg iotop || true
  install_pkg ifstat || true
  install_pkg iftop || true
  install_pkg nethogs || true

  if [ "$IS_WSL" = "1" ]; then
    skip "Skipping linux-tools-generic, nvme-cli, and acpi on WSL"
  else
    install_pkg linux-tools-generic || true  # provides perf
    install_pkg nvme-cli || true
    install_pkg acpi || true
  fi

  install_pkg numactl || true
  install_pkg hwloc || true
  install_pkg lm-sensors || true
  install_pkg smartmontools || true
}

# ----- Networking / SSH -----
install_networking() {
  install_pkg openssh-client || true
  install_pkg autossh || true
  install_pkg mosh || true
  # mtr-tiny is a smaller CLI variant; fallback to mtr if needed
  if apt_has_pkg mtr-tiny; then install_pkg mtr-tiny; else install_pkg mtr || true; fi
  install_pkg nmap || true
  install_pkg traceroute || true
  install_pkg tcpdump || true
  install_pkg net-tools || true

  if [ "$IS_WSL" = "1" ]; then
    skip "Skipping wireshark-common on WSL"
  else
    # Use wireshark-common to avoid GUI; still may prompt, but we set noninteractive
    install_pkg wireshark-common || true
  fi
}

# ----- Filesystems / Storage -----
install_filesystems() {
  install_pkg exfatprogs || true
  install_pkg exfat-fuse || true
  install_pkg ntfs-3g || true
  if [ "$IS_WSL" = "1" ]; then
    skip "Skipping sshfs on WSL"
  else
    install_pkg sshfs || true
  fi
  install_pkg nfs-common || true
  install_pkg cifs-utils || true
  install_pkg mergerfs || true
  install_pkg lsof || true
  install_pkg pstree || true
}

# ----- Compression & Archiving -----
install_archivers() {
  install_pkg zip || true
  install_pkg unzip || true
  install_pkg p7zip-full || true
  install_pkg zstd || true
  install_pkg pigz || true
  install_pkg pbzip2 || true
  install_pkg unar || true
}

# ----- Developer Services CLIs -----
install_dev_clis() {
  # Only install what exists in current repos; we do not add external repos
  if apt_has_pkg kubectl; then install_pkg kubectl; else skip "kubectl not in default repos for this distro"; fi
  if apt_has_pkg helm; then install_pkg helm; else skip "helm not in default repos for this distro"; fi
  install_pkg rclone || true
  # Prefer httpie over curlie
  if apt_has_pkg httpie; then install_pkg httpie; elif apt_has_pkg curlie; then install_pkg curlie; else skip "Neither httpie nor curlie available"; fi
  install_pkg aria2 || true
}

# ----- Editors / Shell / Prompt -----
install_editors_shell() {
  # Try neovim first; if not available, use emacs-nox
  if apt_has_pkg neovim; then install_pkg neovim; elif apt_has_pkg emacs-nox; then install_pkg emacs-nox; else warn "Neither neovim nor emacs-nox available"; fi
  install_pkg direnv || true
  install_pkg starship || true
  install_pkg fonts-powerline || true
  install_pkg fonts-firacode || true
}

# ----- Media / Docs -----
install_media_docs() {
  install_pkg imagemagick || true
  install_pkg ffmpeg || true
  install_pkg pandoc || true
  install_pkg ghostscript || true
  if apt_has_pkg pdftk-java; then install_pkg pdftk-java; elif apt_has_pkg pdftk; then install_pkg pdftk; else skip "pdftk not available (pdftk-java/pdftk)"; fi
}

# ----- Misc -----
install_misc() {
  install_pkg watch || true
  install_pkg whois || true
  install_pkg dnsutils || true
  install_pkg uuid-runtime || true
  install_pkg time || true
  install_pkg colordiff || true
}

# Run installers
if ! require_install_perms; then
  warn "Insufficient privileges or NO_NET=1; nothing to install."
  exit 0
fi

install_qol
install_build_tools
install_system_hw
install_networking
install_filesystems
install_archivers
install_dev_clis
install_editors_shell
install_media_docs
install_misc

log "Extra installs complete."

