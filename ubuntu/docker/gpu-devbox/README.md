# GPU Devbox (NGC PyTorch 25.08, multi-arch)

GPU-focused development environment based on `nvcr.io/nvidia/pytorch:25.08-py3` with CUDA 12.6 + PyTorch 2.8, extended with GPU diagnostics, tooling from the request, and Python dependencies required by [nanuGPT](https://github.com/sytelus/nanuGPT). Builds for **linux/amd64** and **linux/arm64** using Docker Buildx.

Highlights:
- Uses the official NVIDIA PyTorch container (multi-arch; ships CUDA/NCCL/cuDNN pre-tuned by NVIDIA).
- Installs the requested CLI/debugging tooling when available for the active architecture, skipping items that are preloaded by the base image or not suited for containers.
- Creates `/opt/nanugpt-venv` (a virtualenv with `--system-site-packages`) to layer Python deps on top of NVIDIA's stack; interactive shells auto-activate it.
- Pre-installs `pip` dependencies from `nanuGPT`'s `pyproject.toml` plus GPU-centric helpers (`flash-attn`, `torch-tb-profiler`, `nvitop`, `accelerate`).
- Provides a shell greeting summarising GPU/CPU status and pointers to profiling tools.

## Prerequisites

- Docker **24+** with Buildx (Docker Desktop and Ubuntu 24.04 ship this).
- NVIDIA Container Toolkit if you plan to run the image with GPU access on Linux. Docker Desktop on macOS/Windows proxies GPUs automatically.
- For cross-builds on Linux hosts: the scripts install QEMU via `tonistiigi/binfmt` (requires a privileged container once).

Check host/Docker status:

```bash
bash ./docker_info.sh
```

## One-time setup

```bash
./setup-builder.sh
```

- Creates/bootstraps a `gpu-devbox-builder` Buildx builder.
- On native Linux installs `binfmt_misc` handlers required for cross-building arm64.

## Build & run locally (single arch)

```bash
./build_local.sh                # builds for the host arch only, loads into classic docker images
./run.sh -v "$PWD:/workspace"   # drop into the devbox with GPU flags pre-wired
```

`run.sh` expands to:

```bash
docker run --rm -it \
  --gpus all \
  --ipc=host \
  --ulimit memlock=-1 --ulimit stack=67108864 \
  -v "$PWD:/workspace" \
  gpu-devbox:local
```

The greeting banner prints CUDA/PyTorch versions and reminds you about `nvtop`.

## Multi-arch build & push

```bash
# Build once (keeps artifacts in .buildx-cache/ for later push)
./build_multiarch.sh

# Push to Docker Hub (tags YYYY.MM.DD and latest by default)
./push_multiarch.sh IMAGE=sytelus/gpu-devbox TAG=2025.09.13
```

Notes:
- Default platforms: `linux/amd64,linux/arm64` (override with `PLATFORMS=...`).
- `build_multiarch.sh` caches outputs locally (`.buildx-cache` by default). Pushing reuses the cache, so no rebuild is needed.
- Manifest/provenance/SBOM are emitted by Buildx; verify with `./verify.sh sytelus/gpu-devbox:TAG`.

## Tooling installed by the Dockerfile

Packages are grouped by purpose. Items were only installed when available for the target architecture and absent from the base image.

**Core CLI & VCS**: `git-lfs`, `mercurial`, `subversion`, `pass`, `direnv`, `starship`, `micro`, `trash-cli`, `plocate`, `fdupes`, `virt-what`, `sudo`, `rclone`, `lsof`, `pstree`, `vmtouch`, `neofetch`, `screen`.

**GPU / profiling / system diagnostics**: `nvtop`, `nvitop` (pip), `torch-tb-profiler` (pip), `accelerate` (pip), `powertop`, `powerstat`, `inxi`, `procinfo`, `htop`, `btop`, `glances`, `sysstat`, `iotop`, `ifstat`, `iftop`, `nethogs`, `hwloc`, `lm-sensors`, `smartmontools`, `nvme-cli`, `acpi`, `ffmpeg`, `ghostscript`, `pdftk-java`.

**Build & HPC tooling**: `cmake`, `meson`, `libopencv-dev`, `libopenmpi-dev`, `freeglut3-dev`, `libx11-dev`, `libxmu-dev`, `libxi-dev`, `libglu1-mesa`, `libglu1-mesa-dev`, `libfreeimage3`, `libfreeimage-dev`, `libffi-dev`, `libsqlite3-dev`, `clang`, `clang-format`, `clang-tidy`, `lld`, `lldb`, `ccache`, `rsync`, `parallel`, `entr`.

**Everyday CLI productivity**: `ripgrep`, `fd-find` (+ `fd` shim), `bat` (+ `bat` shim), `fzf`, `tldr`, `tree`, `ncdu`, `gdu`, `moreutils`, `rename`, `yq`, `time`, `whois`, `dnsutils`, `autossh`, `mtr`, `nmap`, `traceroute`, `tcpdump`, `net-tools`, `exfat-fuse`, `exfatprogs`, `ntfs-3g`, `sshfs`, `cifs-utils`, `mergerfs`, `p7zip-full`, `zstd`, `pigz`, `pbzip2`, `unar`, `xclip`, `xsel`, `direnv`, `starship`, `fonts-powerline`, `fonts-firacode`.

**Terminal fun (per request)**: `fortune-mod`, `sl`, `espeak`, `figlet`, `sysvbanner`, `cowsay`, `oneko`, `cmatrix`, `toilet`, `pi`, `xcowsay`, `aview`, `bb`, `rig`, `weather-util`.

**Python packages**: `einops`, `wandb`, `mlflow`, `sentencepiece`, `tokenizers`, `tiktoken`, `transformers`, `datasets`, `tqdm`, `matplotlib`, `rich`, `pyarrow==19.0.1`, `orjson`, `tenacity`, `openai`, `numpy`, `pandas`, `scipy`, `accelerate`, `torch-tb-profiler`, `nvitop`, plus a best-effort install of `flash-attn` (`--no-build-isolation`; skips gracefully if wheels are unavailable for the active arch).

During build a `plocate` index is generated so `locate` works out of the box.

## What we did **not** reinstall

The base NVIDIA PyTorch 25.08 image already bundles many requested utilities. We detected these via `dpkg-query` and left them untouched:

- `git`, `curl`, `wget`, `tar`, `xz-utils`, `bash-completion`
- `aptitude`, `build-essential`, `g++`, `zlib1g`, `zlib1g-dev`, `bzip2`, `libglib2.0-0`
- `gcc`, `libstdc++6`, `tmux`, `jq`, `pkg-config`, `ninja-build`
- `autoconf`, `automake`, `libtool`, `gdb`, `valgrind`
- `libssl-dev`, `libbz2-dev`, `liblzma-dev`, `numactl`
- `openssh-client`, `nfs-common`, `zip`, `unzip`, `watch`, `uuid-runtime`
- NVIDIA tooling such as `nvidia-smi`, CUDA compilers, NCCL, and cuDNN

Leaving them alone avoids redundant downloads and keeps NVIDIA-tuned components untouched.

## Requested items that were intentionally excluded

| Item | Reason |
|------|--------|
| `tlp`, `tlp-rdw` | Require systemd and direct hardware control; inside a container they neither start nor provide benefit, and the post-install scripts can hang headless builds.
| `linux-tools-generic` | Tightly couples to the host kernel ABI (`linux-tools-<kernel>`). Cross-building for multiple kernel versions is unreliable; better install matching `linux-tools-$(uname -r)` on the host when you need `perf`.
| `nvidia-smi` | Already included (and maintained) by the NVIDIA base image.
| `git`, `curl`, `wget`, `keychain`, `zlib1g`, etc. | Present upstream; see prior section.
| `nfs-comon` | Typo in request; corrected to `nfs-common` (already present upstream).

If you need TLP/Linux-tools inside a privileged VM rather than a container, install them after launching the container (or prefer host-level tooling).

## nanuGPT readiness

- Python dependencies mirror `pyproject.toml` of `nanuGPT` plus supporting scientific stack (`numpy/pandas/scipy`) and live inside `/opt/nanugpt-venv`. The venv inherits NVIDIA's system packages (`--system-site-packages`) so CUDA/PyTorch remain the tuned builds from the base image.
- The NVIDIA base image already ships CUDA 12.6, cuBLAS, cuDNN, NCCL, and PyTorch 2.8 nightly—no extra CUDA setup required.
- `flash-attn` is attempted on both arches. On `arm64` the build may fall back to source compilation; if it fails a warning is printed but the image build continues.
- Interactive shells automatically activate the venv; for non-interactive commands use `source /opt/nanugpt-venv/bin/activate` first or prefix with `/opt/nanugpt-venv/bin/python`.

To clone and install nanuGPT inside the container:

```bash
git clone https://github.com/sytelus/nanuGPT.git
cd nanuGPT
pip install -e .
```

## Verification tips

- `nvtop` or `nvitop` for live GPU telemetry (requires `--gpus all` at runtime).
- `torch-tb-profiler` integrates with TensorBoard: `tensorboard --logdir <runs>`.
- `flash-attn` integrity: `python -c "import flash_attn; print('flash-attn ok')"`.
- `docker buildx imagetools inspect sytelus/gpu-devbox:TAG` to confirm multi-arch manifest.

## Troubleshooting

- **`no match for platform`**: rerun `./setup-builder.sh` to create/activate the Buildx builder with QEMU.
- **`flash-attn` build failures**: the install is opportunistic. If you need it, rerun inside the container with the matching CUDA toolkit and ensure adequate RAM/cores.
- **`nvtop` requires /dev/nvidia*`**: run `docker run --gpus all ...` or enable the NVIDIA Container Toolkit on Linux.
- **Arm64 builds slower under emulation**: consider using a native arm64 runner for faster Buildx builds.

## Next steps

- Add project-specific dotfiles or mount volumes in `run.sh` (e.g., `RUN_EXTRA_ARGS="-v $HOME/.cache/huggingface:/root/.cache/huggingface" ./run.sh`).
- Integrate with CI by invoking `build_multiarch.sh` inside your pipeline runner, then `push_multiarch.sh` once authenticated.
- Extend the `Dockerfile` with additional profiling stacks (Nsight Systems/Compute) if NVIDIA publishes multi-arch packages in the future.
