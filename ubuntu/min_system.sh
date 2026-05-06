#!/usr/bin/env bash
# fail if any errors
set -euo pipefail
#set -o xtrace

export DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-noninteractive}
export NO_NET=${NO_NET:-0}
export INSTALL_FUN_PACKAGES=${INSTALL_FUN_PACKAGES:-0}

log() { echo "[min_system] $*"; }
warn() { echo "[min_system][WARN] $*" >&2; }

bool_is_true() {
    case "${1:-0}" in
        1|y|Y|yes|YES|true|TRUE|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_DEB="amd64"
        ;;
    aarch64|arm64)
        ARCH_DEB="arm64"
        ;;
    armv7l)
        ARCH_DEB="armhf"
        ;;
    *)
        warn "Unsupported architecture: $ARCH. Some packages may be skipped."
        ARCH_DEB=""
        ;;
esac

IS_WSL=0
if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=1
fi

HAS_SUDO=0
if [ "$(id -u)" = "0" ]; then
    HAS_SUDO=1
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    HAS_SUDO=1
fi

_sudo() {
    if [ "$HAS_SUDO" = "1" ]; then sudo "$@"; else "$@"; fi
}

if [ "$HAS_SUDO" != "1" ]; then
    warn "Sudo/root not available. Skipping system package installation."
    exit 0
fi

if [ "$NO_NET" != "0" ]; then
    warn "NO_NET=$NO_NET. Skipping network-dependent system package installation."
    exit 0
fi

APT_UPDATED=0
apt_update_once() {
    if [ "$APT_UPDATED" = "0" ]; then
        _sudo apt-get update -y || warn "apt-get update failed; continuing with existing package index."
        APT_UPDATED=1
    fi
}

apt_has_pkg() {
    local pkg="$1"
    apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2}' | grep -vq "(none)"
}

install_pkg() {
    local pkg="$1"
    apt_update_once
    if ! apt_has_pkg "$pkg"; then
        warn "Package '$pkg' not available in current APT sources for arch '$ARCH_DEB'. Skipping."
        return 1
    fi

    log "Installing: $pkg"
    _sudo apt-get install -y --no-install-recommends "$pkg" || {
        warn "Failed to install '$pkg'. Continuing."
        return 1
    }
}

install_packages() {
    local pkg
    for pkg in "$@"; do
        install_pkg "$pkg" || true
    done
}

install_first_available() {
    local pkg
    apt_update_once
    for pkg in "$@"; do
        if apt_has_pkg "$pkg"; then
            install_pkg "$pkg"
            return 0
        fi
    done

    warn "None available: $*"
    return 1
}

enable_ubuntu_components() {
    install_pkg software-properties-common || true

    if ! command -v add-apt-repository >/dev/null 2>&1; then
        warn "add-apt-repository unavailable; cannot enable universe/multiverse automatically."
        return 0
    fi

    _sudo add-apt-repository -y universe || warn "Unable to enable universe repository."
    _sudo add-apt-repository -y multiverse || warn "Unable to enable multiverse repository."
    APT_UPDATED=0
    apt_update_once
}

install_core_packages() {
    install_packages \
        git curl wget xclip xsel xz-utils tar apt-transport-https trash-cli bash-completion \
        ufw fail2ban unattended-upgrades at \
        npm nodejs \
        htop procps build-essential cmake g++ libopencv-dev libopenmpi-dev zlib1g-dev \
        fdupes keychain pass micro zlib1g \
        ca-certificates gnupg lsb-release \
        bzip2 libxext6 libsm6 libxrender1 mercurial subversion \
        virt-what sudo freeglut3-dev libx11-dev \
        libxmu-dev libxi-dev libglu1-mesa-dev \
        libfreeimage-dev vmtouch \
        tmux screen vim nano pv pipx bubblewrap unzip

    install_first_available libglib2.0-0t64 libglib2.0-0 || true
    install_first_available libfreeimage3t64 libfreeimage3 || true
    install_first_available plocate locate || true
    install_first_available fastfetch neofetch || true
}

install_desktop_and_fun_packages() {
    install_first_available espeak-ng espeak || true
    install_packages \
        fortune-mod sl figlet sysvbanner cowsay oneko cmatrix toilet pi xcowsay aview bb rig weather-util
}

install_power_and_hardware_packages() {
    if [ "$IS_WSL" = "1" ]; then
        log "Skipping power/hardware packages on WSL."
        return 0
    fi

    install_packages tlp powertop tlp-rdw inxi nvtop powerstat

    # Install nvidia-prime only on x86_64 architecture.
    if [ "$ARCH" = "x86_64" ]; then
        install_pkg nvidia-prime || true
    fi
}

install_toolchain_updates() {
    if command -v add-apt-repository >/dev/null 2>&1; then
        _sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test || warn "Unable to add ubuntu-toolchain-r/test PPA."
        APT_UPDATED=0
    else
        warn "add-apt-repository unavailable; skipping ubuntu-toolchain-r/test PPA."
    fi

    install_pkg gcc || true

    apt_update_once
    if apt_has_pkg libstdc++6; then
        _sudo apt-get install -y --only-upgrade libstdc++6 || warn "Unable to upgrade libstdc++6."
    else
        warn "libstdc++6 not available; skipping upgrade."
    fi
}

install_azure_cli() {
    if ! command -v az >/dev/null 2>&1; then
        log "Azure CLI not found. Installing..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | _sudo bash || warn "Azure CLI installation failed."
    fi

    if command -v az >/dev/null 2>&1; then
        az config set extension.use_dynamic_install=yes_without_prompt || warn "Unable to configure Azure CLI dynamic extension installs."
        _sudo mkdir -p /opt/az/extensions/
        _sudo chmod 1777 /opt/az/extensions/
    else
        warn "Azure CLI is still unavailable; skipping Azure CLI configuration."
    fi

    bash install_azcopy.sh || warn "AzCopy installation failed."
}

install_github_cli() {
    if command -v gh >/dev/null 2>&1; then
        log "GitHub CLI is already installed."
        return 0
    fi

    if [ -z "$ARCH_DEB" ]; then
        warn "Skipping GitHub CLI installation; unsupported architecture '$ARCH'."
        return 0
    fi

    _sudo mkdir -p -m 755 /etc/apt/keyrings
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | _sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
        || { warn "Unable to install GitHub CLI keyring."; return 1; }
    _sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

    echo "deb [arch=$ARCH_DEB signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | _sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

    APT_UPDATED=0
    apt_update_once
    install_pkg gh || true
}

install_user_tools() {
    mkdir -p "$HOME/.local/bin"

    if ! command -v micro >/dev/null 2>&1; then
        (cd "$HOME/.local/bin" && curl https://getmic.ro | MICRO_DESTDIR="$HOME/.local" sh) || warn "micro installer failed."
    fi

    if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash || warn "nvm installer failed."
    fi

    export NVM_DIR="$HOME/.nvm"
    set +u
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
    if command -v nvm >/dev/null 2>&1; then
        nvm install --lts || warn "nvm failed to install latest LTS Node."
        nvm use --lts || warn "nvm failed to activate latest LTS Node."
    fi
    set -u

    install_zellij
    install_rusage
}

install_zellij() {
    if command -v zellij >/dev/null 2>&1; then
        log "Zellij is already installed."
        return 0
    fi

    local zellij_arch=""
    case "$ARCH" in
        x86_64) zellij_arch="x86_64" ;;
        aarch64|arm64) zellij_arch="aarch64" ;;
        *)
            warn "Skipping Zellij installation; no release asset configured for $ARCH."
            return 0
            ;;
    esac

    local tmpdir
    tmpdir="$(mktemp -d)"
    (
        cd "$tmpdir"
        curl -fLO "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${zellij_arch}-unknown-linux-musl.tar.gz"
        tar -xzf "zellij-${zellij_arch}-unknown-linux-musl.tar.gz"
        install -m 0755 zellij "$HOME/.local/bin/zellij"
    ) || warn "Zellij installation failed."
    rm -rf "$tmpdir"
}

install_rusage() {
    if [ "$ARCH" != "x86_64" ]; then
        log "Skipping rusage installation; not available for $ARCH architecture."
        return 0
    fi

    if command -v rusage >/dev/null 2>&1; then
        log "rusage is already installed."
        return 0
    fi

    local tmp_rusage
    tmp_rusage="$(mktemp)"
    if curl -fsSL "https://justine.lol/rusage/rusage.com" -o "$tmp_rusage" \
        || curl -fsSL "https://github.com/jart/cosmopolitan/raw/master/examples/rusage.com" -o "$tmp_rusage"; then
        install -m 0755 "$tmp_rusage" "$HOME/.local/bin/rusage"
    else
        warn "Skipping rusage installation; download failed from both URLs."
    fi
    rm -f "$tmp_rusage"
}

log "Arch(uname)=$ARCH, Arch(deb)=$ARCH_DEB, WSL=$IS_WSL, NO_NET=$NO_NET"

enable_ubuntu_components
install_core_packages
if bool_is_true "$INSTALL_FUN_PACKAGES"; then
    install_desktop_and_fun_packages
else
    log "Fun packages are disabled. Set INSTALL_FUN_PACKAGES=1 to install them."
fi
install_power_and_hardware_packages
install_toolchain_updates
install_azure_cli
install_github_cli
install_pkg zsh || true
bash install_rust.sh || warn "Rust installation failed."
install_user_tools

log "Minimal system setup complete."
