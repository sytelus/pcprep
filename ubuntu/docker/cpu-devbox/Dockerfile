# syntax=docker/dockerfile:1.7
# Multi-arch base (amd64, arm64)
FROM --platform=$TARGETPLATFORM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETPLATFORM
ARG TARGETARCH

# Basic labels (OCI)
ARG VCS_REF
LABEL org.opencontainers.image.source="https://github.com/sytelus/pcprep" \
      org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.title="cpu-devbox"
LABEL org.opencontainers.image.description="Ubuntu 24.04 interactive terminal devbox with Azure/Git/GH CLI, kubectl/helm, AzCopy, Miniconda+ML stack, and a rich toolbox."
LABEL org.opencontainers.image.version="2025.09"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.base.name="ubuntu:24.04"
LABEL org.opencontainers.image.ref.name="cpu-devbox"

ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Enable Universe/Multiverse, baseline packages, and utility repos prerequisites
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends software-properties-common gpg ca-certificates curl wget xz-utils apt-transport-https lsb-release gnupg locales; \
    locale-gen en_US.UTF-8; \
    add-apt-repository -y universe; \
    add-apt-repository -y multiverse; \
    rm -rf /var/lib/apt/lists/*

# ---- Function to install "available" packages only (skip gracefully if missing) ----
# We gather your long lists (from request + tools.txt) and install what exists on each arch.
RUN set -eux; \
    apt-get update; \
    # Core/tooling from your list
    PKGS=" \
      git git-lfs curl wget xclip xsel xz-utils tar trash-cli bash-completion \
      tlp powertop tlp-rdw inxi procinfo htop aptitude \
      build-essential cmake libopencv-dev g++ libopenmpi-dev zlib1g-dev \
      fortune-mod sl espeak figlet sysvbanner cowsay oneko cmatrix toilet pi xcowsay aview bb rig weather-util \
      fdupes plocate keychain pass micro zlib1g \
      bzip2 libglib2.0-0 libxext6 libsm6 libxrender1 mercurial subversion \
      virt-what sudo freeglut3-dev libx11-dev libxmu-dev libxi-dev libglu1-mesa libglu1-mesa-dev libfreeimage3 \
      libfreeimage-dev vmtouch neofetch powerstat gcc libstdc++6 tmux screen \
      # ---- tools.txt (Everyday CLI QoL) ---- \
      ripgrep fd-find bat fzf tldr tree ncdu gdu moreutils rename jq yq parallel entr rsync \
      pkg-config ninja-build meson autoconf automake libtool ccache clang clang-format clang-tidy lld gdb lldb valgrind strace ltrace \
      libssl-dev libffi-dev libbz2-dev liblzma-dev libsqlite3-dev \
      btop glances sysstat iotop ifstat iftop nethogs linux-tools-generic numactl hwloc lm-sensors smartmontools nvme-cli acpi \
      openssh-client autossh mtr nmap traceroute tcpdump net-tools \
      exfatprogs exfat-fuse ntfs-3g sshfs nfs-common cifs-utils mergerfs lsof pstree \
      zip unzip p7zip-full zstd pigz pbzip2 unar \
      rclone  \
      direnv starship fonts-powerline fonts-firacode \
      ffmpeg ghostscript pdftk-java \
      watch whois dnsutils uuid-runtime time  \
      #pandoc imagemagick httpie aria2 neovim emacs-nox mosh colordiff wireshark-common
    "; \
    # Filter to install only packages that exist in current apt index
    # Use batch apt-cache query (much faster than per-package queries)
    INSTALLABLE=""; SKIPPED=""; \
    AVAILABLE_PKGS=$(apt-cache show $PKGS 2>/dev/null | grep '^Package:' | awk '{print $2}' | sort -u || true); \
    for pkg in $PKGS; do \
      if echo "$AVAILABLE_PKGS" | grep -qx "$pkg"; then \
        INSTALLABLE="$INSTALLABLE $pkg"; \
      else \
        SKIPPED="$SKIPPED $pkg"; \
      fi; \
    done; \
    echo "Installing packages:" $INSTALLABLE; \
    if [ -n "$INSTALLABLE" ]; then \
      apt-get install -y --no-install-recommends $INSTALLABLE; \
    fi; \
    if [ -n "$SKIPPED" ]; then echo "Skipped (not available for this arch/repo): $SKIPPED"; fi; \
    # Create friendly symlinks for fd/bat (Debian names are fdfind/batcat)
    if command -v fdfind >/dev/null 2>&1 && [ ! -e /usr/local/bin/fd ]; then ln -s "$(command -v fdfind)" /usr/local/bin/fd; fi; \
    if command -v batcat >/dev/null 2>&1 && [ ! -e /usr/local/bin/bat ]; then ln -s "$(command -v batcat)" /usr/local/bin/bat; fi; \
    # Initialize plocate database if installed
    if command -v updatedb >/dev/null 2>&1; then \
      mkdir -p /var/lib/plocate; \
      updatedb --prunepaths='/proc /sys /dev /run /tmp' || true; \
    fi; \
    rm -rf /var/lib/apt/lists/*

# ---- External repos: Azure CLI, GitHub CLI, kubectl (single apt-get update for speed) ----
# Note: QEMU ARM64 emulation has severe SSL/network issues. This block is fault-tolerant:
# - Uses wget as fallback when curl fails
# - Each repo setup is optional (won't fail the build)
# - zsh is installed from Ubuntu repos as fallback
RUN set -eux; \
    ARCH=$(dpkg --print-architecture); \
    mkdir -p /etc/apt/keyrings; \
    # Helper function: try curl first, fall back to wget, with retries and timeouts
    fetch_url() { \
      url="$1"; dest="$2"; \
      echo "Fetching $url -> $dest"; \
      if curl -fsSL --retry 3 --retry-delay 5 --retry-all-errors --connect-timeout 30 --max-time 120 "$url" -o "$dest" 2>/dev/null; then \
        return 0; \
      elif wget -q --timeout=30 --tries=3 --waitretry=5 -O "$dest" "$url" 2>/dev/null; then \
        return 0; \
      else \
        echo "WARNING: Failed to fetch $url"; \
        return 1; \
      fi; \
    }; \
    # Azure CLI repo (optional - may fail under QEMU)
    if fetch_url "https://packages.microsoft.com/keys/microsoft.asc" "/tmp/microsoft.asc"; then \
      gpg --dearmor < /tmp/microsoft.asc > /etc/apt/keyrings/microsoft.gpg 2>/dev/null || true; \
      if [ -s /etc/apt/keyrings/microsoft.gpg ]; then \
        chmod go+r /etc/apt/keyrings/microsoft.gpg; \
        AZ_DIST="$(lsb_release -cs)"; \
        printf "Types: deb\nURIs: https://packages.microsoft.com/repos/azure-cli/\nSuites: %s\nComponents: main\nArchitectures: %s\nSigned-by: /etc/apt/keyrings/microsoft.gpg\n" "$AZ_DIST" "$ARCH" > /etc/apt/sources.list.d/azure-cli.sources; \
        echo "Azure CLI repo configured"; \
      fi; \
      rm -f /tmp/microsoft.asc; \
    else \
      echo "Skipping Azure CLI repo (download failed)"; \
    fi; \
    # GitHub CLI repo (optional)
    if fetch_url "https://cli.github.com/packages/githubcli-archive-keyring.gpg" "/etc/apt/keyrings/githubcli-archive-keyring.gpg"; then \
      if [ -s /etc/apt/keyrings/githubcli-archive-keyring.gpg ]; then \
        chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
        echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list; \
        echo "GitHub CLI repo configured"; \
      fi; \
    else \
      echo "Skipping GitHub CLI repo (download failed)"; \
    fi; \
    # Kubernetes kubectl repo (optional)
    if fetch_url "https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key" "/tmp/kubernetes.key"; then \
      gpg --dearmor < /tmp/kubernetes.key > /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null || true; \
      if [ -s /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then \
        chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg; \
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' > /etc/apt/sources.list.d/kubernetes.list; \
        echo "Kubernetes repo configured"; \
      fi; \
      rm -f /tmp/kubernetes.key; \
    else \
      echo "Skipping Kubernetes repo (download failed)"; \
    fi; \
    # Update and install whatever packages are available
    apt-get update || true; \
    EXTERNAL_PKGS=""; \
    for pkg in azure-cli gh kubectl zsh; do \
      if apt-cache show "$pkg" >/dev/null 2>&1; then EXTERNAL_PKGS="$EXTERNAL_PKGS $pkg"; fi; \
    done; \
    if [ -n "$EXTERNAL_PKGS" ]; then \
      echo "Installing:$EXTERNAL_PKGS"; \
      apt-get install -y $EXTERNAL_PKGS || true; \
    fi; \
    rm -rf /var/lib/apt/lists/*

# ---- AzCopy (x86_64 & ARM64 tarballs). Skip on other arches. Fault-tolerant for QEMU. ----
RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) AZCOPY_URL="https://aka.ms/downloadazcopy-v10-linux";; \
      arm64) AZCOPY_URL="https://aka.ms/downloadazcopy-v10-linux-arm64";; \
      *) AZCOPY_URL="";; \
    esac; \
    if [ -n "$AZCOPY_URL" ]; then \
      tmpdir="$(mktemp -d)"; \
      echo "Downloading AzCopy from $AZCOPY_URL"; \
      if curl -fsSL --retry 3 --retry-delay 5 --retry-all-errors --connect-timeout 30 --max-time 300 "$AZCOPY_URL" -o "$tmpdir/azcopy.tgz" 2>/dev/null || \
         wget -q --timeout=30 --tries=3 --waitretry=5 -O "$tmpdir/azcopy.tgz" "$AZCOPY_URL" 2>/dev/null; then \
        tar -xzf "$tmpdir/azcopy.tgz" -C "$tmpdir"; \
        install "$tmpdir"/azcopy_linux_*/azcopy /usr/local/bin/azcopy; \
        echo "AzCopy installed successfully"; \
      else \
        echo "WARNING: AzCopy download failed (QEMU network issues); skipping."; \
      fi; \
      rm -rf "$tmpdir"; \
    else echo "AzCopy not published for $TARGETARCH; skipping."; fi

# NOTE: Helm installation is disabled to reduce image size. Uncomment and adapt
# the block below if you need Helm (uses Buildkite-hosted helm-linux repo).

# ---- Install Rust (cargo) and zellij terminal multiplexer (optional - may fail under QEMU) ----
RUN set -eux; \
    echo "Installing Rust and zellij..."; \
    if curl --proto '=https' --tlsv1.2 -sSf --retry 3 --retry-delay 5 --connect-timeout 30 --max-time 120 https://sh.rustup.rs -o /tmp/rustup.sh 2>/dev/null || \
       wget -q --timeout=30 --tries=3 -O /tmp/rustup.sh https://sh.rustup.rs 2>/dev/null; then \
      sh /tmp/rustup.sh -y --default-toolchain stable --profile minimal; \
      rm -f /tmp/rustup.sh; \
      . "$HOME/.cargo/env"; \
      cargo install zellij --locked; \
      cp -r /root/.cargo /etc/skel/; \
      echo "Rust $(rustc --version) and zellij installed."; \
    else \
      echo "WARNING: Rust installation failed (QEMU network issues); skipping Rust and zellij."; \
    fi

# ---- Miniconda/Miniforge installation (multi-arch) ----
ENV CONDA_DIR=/opt/conda \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore \
    # Opt-in to pip 26.2 behavior: --constraint only affects runtime deps, not build deps.
    # Silences deprecation warning about PIP_CONSTRAINT affecting build dependencies.
    PIP_USE_FEATURE=build-constraint
ENV PATH="${CONDA_DIR}/bin:${PATH}"

RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) CONDA_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh";; \
      arm64) CONDA_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh";; \
      *)     echo "Unknown TARGETARCH=$TARGETARCH"; exit 1;; \
    esac; \
    echo "Downloading Miniforge from $CONDA_URL"; \
    if curl -fsSL --retry 3 --retry-delay 5 --retry-all-errors --connect-timeout 60 --max-time 600 "$CONDA_URL" -o /tmp/conda.sh 2>/dev/null || \
       wget -q --timeout=60 --tries=3 --waitretry=10 -O /tmp/conda.sh "$CONDA_URL" 2>/dev/null; then \
      echo "Download successful, installing Miniforge..."; \
    else \
      echo "ERROR: Failed to download Miniforge. Build cannot continue."; \
      exit 1; \
    fi; \
    bash /tmp/conda.sh -b -p "$CONDA_DIR"; \
    rm -f /tmp/conda.sh; \
    rm -rf "$CONDA_DIR/etc/conda"; \
    mkdir -p "$CONDA_DIR/etc/conda"; \
    printf '%s\n' \
      'channel_priority: strict' \
      'channels:' \
      '  - conda-forge' \
      'default_channels:' \
      '  - https://conda.anaconda.org/conda-forge' \
      > "$CONDA_DIR/etc/conda/condarc"; \
    "$CONDA_DIR/bin/conda" update -y -n base --override-channels -c conda-forge conda; \
    "$CONDA_DIR/bin/conda" install -y -n base --override-channels -c conda-forge pip python=3.12; \
    "$CONDA_DIR/bin/conda" clean -afy

# ---- Python stack in base env (CPU‑only). Batch install for speed. ----
# Packages requested (deduped): rich pandas scikit-learn matplotlib jupyter tensorflow tensorboard keras pytorch transformers datasets wandb
# accelerate einops tokenizers sentencepiece evaluate mlflow natsort omegaconf pebble pre-commit pygtrie pytest typing-extensions tiktoken tqdm
RUN --mount=type=cache,target=/root/.cache/pip \
    set -eux; \
    # Batch install via conda (single dependency resolution is MUCH faster than per-package)
    # These packages are reliably available on conda-forge for both amd64/arm64
    CONDA_PKGS="rich pandas scikit-learn matplotlib jupyter tensorboard tqdm pytest typing-extensions"; \
    echo "Installing conda packages: $CONDA_PKGS"; \
    "$CONDA_DIR/bin/conda" install -y -n base -c conda-forge $CONDA_PKGS; \
    # Remaining packages install faster via pip (avoids slow conda search/resolve per package)
    PIP_PKGS="keras transformers datasets wandb accelerate einops tokenizers sentencepiece evaluate mlflow natsort omegaconf pebble pre-commit pygtrie tiktoken"; \
    echo "Installing pip packages: $PIP_PKGS"; \
    "$CONDA_DIR/bin/pip" install --no-cache-dir $PIP_PKGS; \
    # TensorFlow & PyTorch (CPU): attempt via conda-forge on amd64/arm64; skip if unavailable
    if [ "$TARGETARCH" = "amd64" ] || [ "$TARGETARCH" = "arm64" ]; then \
      "$CONDA_DIR/bin/conda" install -y -n base -c conda-forge tensorflow || echo "tensorflow not available; skipped"; \
      # For pytorch, conda-forge provides CPU builds; if resolution fails, try pytorch channel (amd64)
      "$CONDA_DIR/bin/conda" install -y -n base -c conda-forge pytorch || \
      "$CONDA_DIR/bin/conda" install -y -n base -c pytorch -c conda-forge pytorch cpuonly || echo "pytorch not available; skipped"; \
    fi; \
    "$CONDA_DIR/bin/conda" clean -afy

# ---- Dotfiles for interactive use ----
# We vendor the repo's dotfiles to avoid network fetches and keep builds reproducible.
COPY ubuntu/.bashrc /root/.bashrc
COPY ubuntu/.inputrc /root/.inputrc
COPY ubuntu/.bash_aliases /root/.bash_aliases
COPY ubuntu/.tmux.conf /root/.tmux.conf
RUN set -eux; \
    mkdir -p /etc/skel; \
    cp -a /root/.bashrc /root/.inputrc /root/.bash_aliases /root/.tmux.conf /etc/skel/; \
    # Ensure conda auto-activation for interactive shells + greeting (only once per session)
    echo '' >> /etc/bash.bashrc; \
    echo '# --- CPU devbox bootstrap ---' >> /etc/bash.bashrc; \
    echo 'if [ -n "$PS1" ]; then' >> /etc/bash.bashrc; \
    echo '  if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi' >> /etc/bash.bashrc; \
    echo '  if [ -f "'"$CONDA_DIR"'/etc/profile.d/conda.sh" ]; then . "'"$CONDA_DIR"'/etc/profile.d/conda.sh"; conda activate base; fi' >> /etc/bash.bashrc; \
    echo '  if [ -z "${DEVBOX_WELCOMED:-}" ]; then export DEVBOX_WELCOMED=1; /usr/local/bin/devbox-greeting || true; fi' >> /etc/bash.bashrc; \
    echo 'fi' >> /etc/bash.bashrc

# Mark that we're inside the devbox container so dotfiles can adjust behavior.
ENV DEVBOX_CONTAINER=1

# ---- Git config: LF line endings preference ----
RUN set -eux; \
    git config --global core.eol lf; \
    git config --global core.autocrlf input

# ---- Friendly greeting script shown at interactive start ----
RUN <<'EOF'
set -eux
cat >/usr/local/bin/devbox-greeting <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
echo "Welcome to CPU devbox!"
cores=$( (nproc 2>/dev/null) || echo "N/A")
mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
mem_gb=$(awk -v kb="${mem_kb}" 'BEGIN{printf "%.1f", kb/1024/1024}')
arch=$(uname -m 2>/dev/null || echo unknown)
kernel=$(uname -r 2>/dev/null || echo unknown)
host=$(hostname 2>/dev/null || echo container)
echo "Host: ${host} | Arch: ${arch} | Kernel: ${kernel} | Cores: ${cores} | RAM: ${mem_gb}G"
# Helpful versions if present
command -v az >/dev/null 2>&1 && az version 2>/dev/null | sed -n 's/.*"azure-cli": "\(.*\)".*/Azure CLI: \1/p'
command -v gh >/dev/null 2>&1 && gh --version | head -n1
command -v kubectl >/dev/null 2>&1 && kubectl version --client 2>/dev/null | head -n1 || true
command -v helm >/dev/null 2>&1 && helm version --short 2>/dev/null || true
python -V 2>/dev/null || true
EOS
chmod +x /usr/local/bin/devbox-greeting
EOF

# Basic health check to verify Python and conda are functional.
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import sys; print(f'Python {sys.version_info.major}.{sys.version_info.minor} OK')" || exit 1

# Default to login shell so /etc/bash.bashrc runs (activates conda + greeting)
CMD ["/bin/bash", "-l"]
