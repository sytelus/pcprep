# syntax=docker/dockerfile:1.7
FROM nvcr.io/nvidia/pytorch:25.11-py3

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETPLATFORM
ARG TARGETARCH
ARG VCS_REF
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.source="https://github.com/sytelus/pcprep" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.title="gpu-devbox" \
      org.opencontainers.image.description="NVIDIA PyTorch 25.11 based devbox with multi-arch tooling, GPU diagnostics, and ML/DL packages preinstalled." \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.base.name="nvcr.io/nvidia/pytorch:25.11-py3"

ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DEVBOX_CONTAINER=1

# Install system packages: base tools, locale setup, and toolbox packages.
# Skips packages already in the base image or unavailable on target architecture.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates locales software-properties-common gnupg; \
    locale-gen en_US.UTF-8; \
    PKGS=" \
      git-lfs \
      xclip xsel trash-cli \
      inxi procinfo htop powertop \
      cmake libopencv-dev libopenmpi-dev \
      fortune-mod sl espeak figlet sysvbanner cowsay oneko cmatrix toilet pi xcowsay aview bb rig weather-util \
      fdupes plocate pass micro \
      mercurial subversion virt-what sudo \
      freeglut3-dev libx11-dev libxmu-dev libxi-dev libglu1-mesa libglu1-mesa-dev libfreeimage3 libfreeimage-dev \
      vmtouch neofetch powerstat screen \
      ripgrep fd-find bat fzf tldr tree ncdu gdu moreutils rename yq parallel entr rsync \
      meson ccache clang clang-format clang-tidy lld lldb strace ltrace \
      libffi-dev libsqlite3-dev \
      btop glances sysstat iotop ifstat iftop nethogs hwloc lm-sensors smartmontools nvme-cli acpi \
      nsight-systems-cli nsight-compute \
      autossh mtr nmap traceroute tcpdump net-tools \
      exfatprogs exfat-fuse ntfs-3g sshfs cifs-utils mergerfs lsof pstree \
      p7zip-full zstd pigz pbzip2 unar \
      rclone direnv starship fonts-powerline fonts-firacode \
      ffmpeg ghostscript pdftk-java \
      whois dnsutils time nvtop \
      zsh \
    "; \
    INSTALLABLE=""; PREINSTALLED=""; SKIPPED=""; \
    INSTALLED_PKGS=$(dpkg-query -W -f='${Package}\n' 2>/dev/null || true); \
    AVAILABLE_PKGS=$(apt-cache show $PKGS 2>/dev/null | grep '^Package:' | awk '{print $2}' | sort -u || true); \
    for pkg in $PKGS; do \
      if echo "$INSTALLED_PKGS" | grep -qx "$pkg"; then \
        PREINSTALLED="$PREINSTALLED $pkg"; \
      elif echo "$AVAILABLE_PKGS" | grep -qx "$pkg"; then \
        INSTALLABLE="$INSTALLABLE $pkg"; \
      else \
        SKIPPED="$SKIPPED $pkg"; \
      fi; \
    done; \
    if [ -n "$INSTALLABLE" ]; then \
      apt-get install -y --no-install-recommends $INSTALLABLE; \
    fi; \
    if command -v fdfind >/dev/null 2>&1 && [ ! -e /usr/local/bin/fd ]; then \
      ln -s "$(command -v fdfind)" /usr/local/bin/fd; \
    fi; \
    if command -v batcat >/dev/null 2>&1 && [ ! -e /usr/local/bin/bat ]; then \
      ln -s "$(command -v batcat)" /usr/local/bin/bat; \
    fi; \
    if command -v updatedb >/dev/null 2>&1; then \
      mkdir -p /var/lib/plocate; \
      updatedb --prunepaths='/proc /sys /dev /run /tmp' || true; \
    fi; \
    rm -rf /var/lib/apt/lists/*; \
    echo "Preinstalled from base image:$PREINSTALLED"; \
    if [ -n "$SKIPPED" ]; then echo "Skipped (arch/unavailable):$SKIPPED"; fi

# Install Oh My Zsh for enhanced shell experience (optional - users can switch with 'chsh -s /bin/zsh').
RUN set -eux; \
    if command -v zsh >/dev/null 2>&1; then \
      export RUNZSH=no CHSH=no KEEP_ZSHRC=yes; \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true; \
      if [ -d /root/.oh-my-zsh ]; then \
        sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' /root/.zshrc; \
        cp -r /root/.oh-my-zsh /etc/skel/; \
        cp /root/.zshrc /etc/skel/; \
        echo "Oh My Zsh installed. Switch shell with: chsh -s /bin/zsh"; \
      fi; \
    else \
      echo "Zsh not available, skipping Oh My Zsh installation."; \
    fi

# Build args for optional packages that may have version conflicts with base image.
# Set to "true" to enable; disabled by default until newer base images resolve conflicts.
ARG INSTALL_VLLM="false"

# Install additional Python packages for ML/DL development directly into the base image.
# Generates constraints from base image packages to prevent any downgrades.
RUN --mount=type=cache,target=/root/.cache/pip \
    set -eux; \
    # Generate constraints from ALL packages in base image to prevent downgrades
    echo "=== Generating constraints from base image packages ===" ; \
    pip freeze > /opt/base-image-constraints.txt ; \
    echo "Base image has $(wc -l < /opt/base-image-constraints.txt) packages" ; \
    # Upgrade pip tooling
    pip install --upgrade pip setuptools wheel packaging; \
    # Install packages with constraints to prevent base image package downgrades
    pip install --no-cache-dir \
      --constraint /opt/base-image-constraints.txt \
      accelerate \
      azure-identity \
      azure-keyvault-secrets \
      azure-storage-blob \
      datasets \
      deepspeed \
      einops \
      evaluate \
      huggingface-hub \
      ipython \
      lightning \
      lm-eval \
      matplotlib \
      math-verify[antlr4_9_3] \
      mlflow \
      natsort \
      nbsphinx \
      omegaconf \
      openai \
      orjson \
      pandas \
      peft \
      pre-commit \
      pydata-sphinx-theme \
      pylatexenc \
      pytest \
      pyzmq \
      ray \
      redis \
      rich \
      safetensors \
      sentencepiece \
      sphinx \
      sphinx-book-theme \
      sphinx-copybutton \
      sphinx-togglebutton \
      tenacity \
      tensorboard \
      tf-keras \
      tiktoken \
      tokenizers \
      torch-tb-profiler \
      torchao \
      transformer-engine[pytorch] \
      transformers \
      trl \
      tqdm \
      typer \
      typing-extensions \
      wandb \
      nvitop; \
    # Optional: vllm (disabled by default - has strict torch version requirements)
    if [ "${INSTALL_VLLM}" = "true" ]; then \
      echo "Installing vllm (INSTALL_VLLM=true)..."; \
      pip install --no-cache-dir --constraint /opt/base-image-constraints.txt vllm || \
        echo "WARNING: vllm installation failed due to version conflicts"; \
    else \
      echo "Skipping vllm (set INSTALL_VLLM=true to enable)"; \
    fi; \
    # Architecture-specific installations
    if [ "${TARGETARCH}" = "amd64" ]; then \
      echo "Attempting flash-attn installation on amd64..."; \
      if pip install --no-cache-dir --constraint /opt/base-image-constraints.txt flash-attn --no-build-isolation; then \
        echo "flash-attn installed successfully."; \
      else \
        echo "flash-attn install failed (wheels may not be available for this CUDA/Python version)."; \
      fi; \
    elif [ "${TARGETARCH}" = "arm64" ]; then \
      echo "Skipping flash-attn on arm64 (no prebuilt wheels; source build requires excessive time/memory)."; \
    else \
      echo "flash-attn unsupported on ${TARGETARCH}."; \
    fi

WORKDIR /workspace

# Reuse repo dotfiles for consistent shell experience (leave base .bashrc untouched).
COPY ubuntu/.bash_aliases /root/.bash_aliases
COPY ubuntu/.inputrc /root/.inputrc
COPY ubuntu/.tmux.conf /root/.tmux.conf

# Create greeting script, profile setup, and copy dotfiles to skeleton for new users.
RUN set -eux; \
    cat <<'EOS' >/usr/local/bin/gpu-devbox-greeting
#!/usr/bin/env bash
set -euo pipefail
echo "Welcome to GPU devbox!"
cores=$( (nproc 2>/dev/null) || echo "N/A")
mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
mem_gb=$(awk -v kb="${mem_kb}" 'BEGIN{printf "%.1f", kb/1024/1024}')
arch=$(uname -m 2>/dev/null || echo unknown)
kernel=$(uname -r 2>/dev/null || echo unknown)
if command -v python3 >/dev/null 2>&1; then pyver=$(python3 -c 'import platform; print(platform.python_version())'); else pyver=N/A; fi
if python3 -c 'import torch' >/dev/null 2>&1; then torchver=$(python3 -c 'import torch; print(torch.__version__)'); cudaver=$(python3 -c 'import torch; print(torch.version.cuda)'); else torchver=N/A; cudaver=N/A; fi
echo "Arch: ${arch} | Kernel: ${kernel} | Cores: ${cores} | RAM: ${mem_gb}G | Python: ${pyver} | Torch: ${torchver} | CUDA: ${cudaver}"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null || true
  nvidia-smi -L 2>/dev/null || true
else
  echo "nvidia-smi unavailable (likely running without --gpus)."
fi
if command -v nvtop >/dev/null 2>&1; then
  echo "Tip: run 'nvtop' for live GPU telemetry."
fi
EOS
    chmod +x /usr/local/bin/gpu-devbox-greeting; \
    cat <<'EOS' >/etc/profile.d/00-gpu-devbox.sh
#!/bin/bash
if [[ $- == *i* ]]; then
  if [[ -z "${GPU_DEVBOX_WELCOMED:-}" ]]; then
    export GPU_DEVBOX_WELCOMED=1
    /usr/local/bin/gpu-devbox-greeting || true
  fi
  if [ -d /root/.local/bin ] && [[ ":$PATH:" != *":/root/.local/bin:"* ]]; then
    export PATH="/root/.local/bin:$PATH"
  fi
fi
EOS
    chmod +x /etc/profile.d/00-gpu-devbox.sh; \
    mkdir -p /etc/skel; \
    cp -a /root/.bash_aliases /root/.inputrc /root/.tmux.conf /etc/skel/

# Basic health check to verify Python and torch are functional.
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import torch; print(f'torch {torch.__version__} OK')" || exit 1

CMD ["/bin/bash", "-l"]
