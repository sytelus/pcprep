# syntax=docker/dockerfile:1.7
FROM nvcr.io/nvidia/pytorch:25.08-py3

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETPLATFORM
ARG TARGETARCH
ARG VCS_REF
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.source="https://github.com/sytelus/pcprep" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.title="gpu-devbox" \
      org.opencontainers.image.description="NVIDIA PyTorch 25.08 based devbox with multi-arch tooling, GPU diagnostics, and nanuGPT dependencies preinstalled." \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.base.name="nvcr.io/nvidia/pytorch:25.08-py3"

ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DEVBOX_CONTAINER=1

# Refresh apt metadata and install requested tooling that is not already provided by the base image.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates locales software-properties-common gnupg; \
    locale-gen en_US.UTF-8; \
    rm -rf /var/lib/apt/lists/*

# Install toolbox packages (skip ones already in the base image or missing on this arch).
RUN set -eux; \
    apt-get update; \
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
      autossh mtr nmap traceroute tcpdump net-tools \
      exfatprogs exfat-fuse ntfs-3g sshfs cifs-utils mergerfs lsof pstree \
      p7zip-full zstd pigz pbzip2 unar \
      rclone direnv starship fonts-powerline fonts-firacode \
      ffmpeg ghostscript pdftk-java \
      whois dnsutils time nvtop \
    "; \
    INSTALLABLE=""; PREINSTALLED=""; SKIPPED=""; \
    for pkg in $PKGS; do \
      if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then \
        PREINSTALLED="$PREINSTALLED $pkg"; \
      elif apt-cache show --no-all-versions "$pkg" >/dev/null 2>&1; then \
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
    if command -v plocate-build >/dev/null 2>&1; then \
      mkdir -p /var/lib/mlocate; \
      plocate-build /var/lib/mlocate/plocate.db / || true; \
    fi; \
    rm -rf /var/lib/apt/lists/*; \
    echo "Preinstalled from base image:$PREINSTALLED"; \
    if [ -n "$SKIPPED" ]; then echo "Skipped (arch/unavailable):$SKIPPED"; fi

# Upgrade pip tooling and install Python dependencies for nanuGPT and GPU profiling utilities.
RUN --mount=type=cache,target=/root/.cache/pip \
    set -eux; \
    python3 -m pip install --upgrade pip setuptools wheel packaging; \
    python3 -m pip install --no-cache-dir \
      numpy pandas scipy \
      einops wandb mlflow sentencepiece tokenizers tiktoken transformers datasets tqdm matplotlib rich pyarrow orjson tenacity openai \
      accelerate torch-tb-profiler nvitop; \
    if [ "${TARGETARCH}" = "amd64" ] || [ "${TARGETARCH}" = "arm64" ]; then \
      python3 -m pip install --no-cache-dir flash-attn --no-build-isolation || echo "flash-attn skipped on ${TARGETARCH}"; \
    else \
      echo "flash-attn unsupported on ${TARGETARCH}"; \
    fi

WORKDIR /workspace

# Provide a friendly greeting and environment bootstrap when entering the container interactively.
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
    chmod +x /etc/profile.d/00-gpu-devbox.sh

# Reuse repo dotfiles for consistent shell experience.
COPY ../../.bashrc /root/.bashrc
COPY ../../.bash_aliases /root/.bash_aliases
COPY ../../.inputrc /root/.inputrc
COPY ../../.tmux.conf /root/.tmux.conf
RUN set -eux; \
    mkdir -p /etc/skel; \
    cp -a /root/.bashrc /root/.bash_aliases /root/.inputrc /root/.tmux.conf /etc/skel/; \
    echo "alias ll='ls -alF'" >> /root/.bash_aliases; \
    echo "alias la='ls -A'" >> /root/.bash_aliases

CMD ["/bin/bash", "-l"]
