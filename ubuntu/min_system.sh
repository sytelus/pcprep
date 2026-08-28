#!/usr/bin/env bash
# fail if any errors
set -euo pipefail
#set -o xtrace

export DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-noninteractive}
export NO_NET=${NO_NET:-0}
export INSTALL_FUN_PACKAGES=${INSTALL_FUN_PACKAGES:-0}
export NVM_VERSION=${NVM_VERSION:-0.40.6}
export ALLOW_UNSUPPORTED_AZURE_CLI=${ALLOW_UNSUPPORTED_AZURE_CLI:-0}
export AZURE_CLI_FALLBACK_SUITE=${AZURE_CLI_FALLBACK_SUITE:-noble}
export INSTALL_TOOLCHAIN_TEST_PPA=${INSTALL_TOOLCHAIN_TEST_PPA:-0}
export REMOVE_LEGACY_TOOLCHAIN_TEST_PPA=${REMOVE_LEGACY_TOOLCHAIN_TEST_PPA:-0}
export RUSAGE_URL=${RUSAGE_URL:-https://cosmo.zip/pub/cosmos/bin/rusage}
export RUSAGE_SHA256=${RUSAGE_SHA256:-270e10853812f6c650f0eb4773354070a398f41738b95c4cb9f7e2f918d4833b}

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

_sudo() {
    if [ "$(id -u)" = "0" ]; then "$@"; else sudo "$@"; fi
}

if [ "$(id -u)" != "0" ]; then
    command -v sudo >/dev/null 2>&1 || { warn "sudo is required for system package installation."; exit 1; }
    sudo -n true 2>/dev/null || sudo -v \
        || { warn "Unable to acquire sudo; refusing a partial bootstrap."; exit 1; }
fi

if [ "$NO_NET" != "0" ]; then
    warn "NO_NET=$NO_NET. Skipping network-dependent system package installation."
    exit 0
fi

APT_UPDATED=0
apt_update_once() {
    if [ "$APT_UPDATED" = "0" ]; then
        _sudo apt-get update -y
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
        git curl wget xclip xsel xz-utils tar apt-transport-https trash-cli bash-completion pciutils \
        ufw fail2ban unattended-upgrades at \
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
    local ppa_url="ppa.launchpadcontent.net/ubuntu-toolchain-r/test/ubuntu"
    local ppa_configured=0

    if grep -RqsF "$ppa_url" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
        ppa_configured=1
    fi

    if bool_is_true "$INSTALL_TOOLCHAIN_TEST_PPA"; then
        if command -v add-apt-repository >/dev/null 2>&1; then
            _sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test \
                || warn "Unable to add ubuntu-toolchain-r/test PPA."
            APT_UPDATED=0
        else
            warn "add-apt-repository unavailable; cannot enable ubuntu-toolchain-r/test."
        fi
    elif bool_is_true "$REMOVE_LEGACY_TOOLCHAIN_TEST_PPA" && (( ppa_configured )); then
        if command -v add-apt-repository >/dev/null 2>&1; then
            log "Removing the legacy ubuntu-toolchain-r/test PPA."
            _sudo add-apt-repository --remove -y ppa:ubuntu-toolchain-r/test \
                || warn "Unable to remove ubuntu-toolchain-r/test PPA."
            APT_UPDATED=0
        else
            warn "add-apt-repository unavailable; cannot remove ubuntu-toolchain-r/test."
        fi
    else
        log "Using Ubuntu's supported toolchain packages; the test-build PPA is disabled."
        if (( ppa_configured )); then
            warn "ubuntu-toolchain-r/test is already configured. Set REMOVE_LEGACY_TOOLCHAIN_TEST_PPA=1 to remove it."
        fi
    fi

    install_pkg gcc || true

    apt_update_once
    if apt_has_pkg libstdc++6; then
        _sudo apt-get install -y --only-upgrade libstdc++6 || warn "Unable to upgrade libstdc++6."
    else
        warn "libstdc++6 not available; skipping upgrade."
    fi
}

azure_cli_repo_has_package() {
    local suite="$1"
    local deb_arch=""

    deb_arch=$(dpkg --print-architecture)
    curl -fsSL --retry 3 \
        "https://packages.microsoft.com/repos/azure-cli/dists/${suite}/main/binary-${deb_arch}/Packages.gz" \
        | gzip -dc \
        | awk '$0 == "Package: azure-cli" { found=1 } END { exit !found }'
}

azure_cli_configured_suite() {
    local source_file=""

    for source_file in \
        /etc/apt/sources.list.d/azure-cli.sources \
        /etc/apt/sources.list.d/azure-cli.list; do
        [ -r "$source_file" ] || continue
        if [[ $source_file == *.sources ]]; then
            awk '$1 == "Suites:" { print $2; exit }' "$source_file"
        else
            awk '
                $1 == "deb" {
                    for (i = 1; i <= NF; i++) {
                        if ($i ~ /packages\.microsoft\.com\/repos\/azure-cli/) {
                            print $(i + 1)
                            exit
                        }
                    }
                }
            ' "$source_file"
        fi
        return 0
    done
}

run_azure_cli_installer() {
    local forced_suite="${1:-}"

    if [ -n "$forced_suite" ]; then
        curl -fsSL --retry 3 https://aka.ms/InstallAzureCLIDeb \
            | _sudo env DIST_CODE="$forced_suite" bash
    else
        curl -fsSL --retry 3 https://aka.ms/InstallAzureCLIDeb \
            | _sudo bash
    fi
}

install_azure_cli() {
    local os_id="" os_codename="" configured_suite="" native_available=0

    os_id=$(. /etc/os-release; printf '%s' "${ID:-}")
    os_codename=$(. /etc/os-release; printf '%s' "${VERSION_CODENAME:-}")
    configured_suite=$(azure_cli_configured_suite || true)

    if [ -n "$os_codename" ] && azure_cli_repo_has_package "$os_codename"; then
        native_available=1
    fi

    if (( native_available )); then
        if ! command -v az >/dev/null 2>&1 || [ "$configured_suite" != "$os_codename" ]; then
            log "Configuring Azure CLI from its native $os_codename repository."
            run_azure_cli_installer \
                || warn "Azure CLI installation failed."
        else
            log "Azure CLI is already configured from its native $os_codename repository."
        fi
    elif ! command -v az >/dev/null 2>&1; then
        if bool_is_true "$ALLOW_UNSUPPORTED_AZURE_CLI"; then
            case $AZURE_CLI_FALLBACK_SUITE in
                jammy|noble) ;;
                *)
                    warn "Unsupported AZURE_CLI_FALLBACK_SUITE=$AZURE_CLI_FALLBACK_SUITE; expected jammy or noble."
                    return 1
                    ;;
            esac
            if ! azure_cli_repo_has_package "$AZURE_CLI_FALLBACK_SUITE"; then
                warn "Azure CLI fallback repository '$AZURE_CLI_FALLBACK_SUITE' has no package for this architecture."
            else
                warn "No native Azure CLI package exists for $os_id/$os_codename; using unsupported $AZURE_CLI_FALLBACK_SUITE fallback by explicit request."
                run_azure_cli_installer "$AZURE_CLI_FALLBACK_SUITE" \
                    || warn "Azure CLI installation failed."
            fi
        else
            warn "No native Azure CLI package exists for $os_id/$os_codename; skipping it. Set ALLOW_UNSUPPORTED_AZURE_CLI=1 to opt into a cross-release fallback."
        fi
    elif [ -n "$configured_suite" ] && [ "$configured_suite" != "$os_codename" ]; then
        warn "Azure CLI remains configured from unsupported suite '$configured_suite'; native '$os_codename' packages are not available yet."
    else
        warn "Azure CLI is installed, but no native $os_codename repository package is currently available."
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
    local installed_nvm_version=""

    mkdir -p "$HOME/.local/bin"

    if ! command -v micro >/dev/null 2>&1; then
        (cd "$HOME/.local/bin" && curl https://getmic.ro | MICRO_DESTDIR="$HOME/.local" sh) || warn "micro installer failed."
    fi

    export NVM_DIR="$HOME/.nvm"
    set +u
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    if command -v nvm >/dev/null 2>&1; then
        installed_nvm_version=$(nvm --version)
    fi
    set -u

    if [ "$installed_nvm_version" != "$NVM_VERSION" ]; then
        log "Installing NVM $NVM_VERSION (found ${installed_nvm_version:-none})."
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" \
            | bash \
            || warn "nvm installer failed."
    fi

    set +u
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
    command -v nvm >/dev/null 2>&1 \
        || { set -u; warn "NVM is unavailable after installation."; return 1; }
    installed_nvm_version=$(nvm --version)
    [ "$installed_nvm_version" = "$NVM_VERSION" ] \
        || { set -u; warn "Expected NVM $NVM_VERSION, found $installed_nvm_version."; return 1; }
    nvm install --lts || { set -u; warn "nvm failed to install latest LTS Node."; return 1; }
    nvm use --lts || { set -u; warn "nvm failed to activate latest LTS Node."; return 1; }
    nvm alias default 'lts/*' \
        || { set -u; warn "nvm failed to make the LTS release the default Node."; return 1; }
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
    local installed_rusage="$HOME/.local/bin/rusage"

    case $ARCH in
        x86_64|aarch64|arm64) ;;
        *)
            log "Skipping rusage installation; unsupported architecture $ARCH."
            return 0
            ;;
    esac

    if ! [[ $RUSAGE_SHA256 =~ ^[0-9a-f]{64}$ ]]; then
        warn "Skipping rusage installation; RUSAGE_SHA256 must be 64 lowercase hexadecimal characters."
        return 0
    fi
    if [ -f "$installed_rusage" ] \
        && printf '%s  %s\n' "$RUSAGE_SHA256" "$installed_rusage" | sha256sum -c - >/dev/null 2>&1; then
        log "The checksum-verified rusage binary is already installed."
        return 0
    fi
    if [ ! -e "$installed_rusage" ] && command -v rusage >/dev/null 2>&1; then
        log "An externally managed rusage command is already available; leaving it unchanged."
        return 0
    fi

    local tmp_rusage
    tmp_rusage="$(mktemp)"
    if curl -fsSL --retry 3 "$RUSAGE_URL" -o "$tmp_rusage" \
        && printf '%s  %s\n' "$RUSAGE_SHA256" "$tmp_rusage" | sha256sum -c - >/dev/null; then
        install -m 0755 "$tmp_rusage" "$installed_rusage"
        log "Installed checksum-verified rusage for $ARCH."
    else
        warn "Skipping rusage installation; download or SHA-256 verification failed."
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

required_commands=(git curl wget tar npm node cmake g++ tmux zsh)
missing_commands=()
for required in "${required_commands[@]}"; do
    command -v "$required" >/dev/null 2>&1 || missing_commands+=("$required")
done
if (( ${#missing_commands[@]} )); then
    printf '[min_system][ERROR] Required commands missing after installation:\n' >&2
    printf '  - %s\n' "${missing_commands[@]}" >&2
    exit 1
fi

log "Minimal system setup complete."
