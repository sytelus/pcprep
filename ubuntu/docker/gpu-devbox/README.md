# GPU Devbox (NGC PyTorch 25.11, Multi-arch)

GPU-focused development environment based on `nvcr.io/nvidia/pytorch:25.11-py3` with CUDA 12.x + PyTorch, extended with GPU diagnostics, development tooling, and Python dependencies required by [nanuGPT](https://github.com/sytelus/nanuGPT). Builds for **linux/amd64** and **linux/arm64** using Docker Buildx.

## Features

- **NVIDIA PyTorch base** - Official NVIDIA container with CUDA/NCCL/cuDNN pre-tuned
- **Multi-architecture** - Builds for both amd64 (x86_64) and arm64 (aarch64)
- **Python virtualenv** - `/opt/nanugpt-venv` with `--system-site-packages` to layer deps on NVIDIA's stack
- **GPU diagnostics** - `nvtop`, `nvitop`, `nvidia-smi`, `torch-tb-profiler`
- **Development tools** - Comprehensive CLI tooling for development, debugging, and profiling
- **Shell greeting** - Displays GPU/CPU status and environment info on login

## Quick Start

```bash
# One-time setup (creates buildx builder with QEMU for cross-arch)
./setup-builder.sh

# Build for local architecture
./build_local.sh

# Run with GPU access
./run.sh -v "$PWD:/workspace"

# Run without GPU (CPU-only mode)
./run.sh --no-gpu -v "$PWD:/workspace"
```

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Docker | Version 24+ with Buildx (included in Docker Desktop and Ubuntu 24.04+) |
| NVIDIA Container Toolkit | Required for GPU access on Linux hosts |
| QEMU (Linux only) | Auto-installed by `setup-builder.sh` for cross-arch builds |

Check your environment:

```bash
./docker_info.sh
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `setup-builder.sh` | One-time setup: creates buildx builder with QEMU for cross-arch builds |
| `build_local.sh` | Build for host architecture only, loads into local Docker |
| `build_multiarch.sh` | Build for amd64+arm64 without pushing (caches to `.buildx-cache/`) |
| `push_multiarch.sh` | Build and push multi-arch image to Docker Hub |
| `run.sh` | Run container with GPU flags (auto-detects GPU availability) |
| `verify.sh` | Inspect multi-arch manifest of a pushed image |
| `docker_info.sh` | Display Docker environment diagnostics |
| `dockerprune.sh` | Clean up unused Docker resources (destructive!) |

### Environment Variables

All build scripts support these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `IMAGE` | `gpu-devbox` / `sytelus/gpu-devbox` | Image name |
| `TAG` | `local` / `YYYY.MM.DD` | Image tag |
| `PLATFORMS` | `linux/amd64,linux/arm64` | Target platforms |
| `BUILD_CONTEXT` | Repository root | Docker build context |
| `BUILDER` | `gpu-devbox-builder` | Buildx builder name |
| `DOCKERFILE` | Auto-detected | Path to Dockerfile |
| `VCS_REF` | Git HEAD short SHA | Version control reference for labels |
| `CACHE_DIR` | `.buildx-cache` | Build cache directory |
| `SKIP_LOGIN` | `0` | Set to `1` to skip Docker login (CI mode) |

## Architecture-Specific Availability

### Python Packages

| Package | amd64 | arm64 | Notes |
|---------|:-----:|:-----:|-------|
| PyTorch | Yes | Yes | From NVIDIA base image |
| CUDA/cuDNN | Yes | Yes | From NVIDIA base image |
| flash-attn | Yes | No | No prebuilt arm64 wheels; source build too slow |
| vllm | Yes | Partial | May have limited functionality on arm64 |
| deepspeed | Yes | Yes | |
| transformer-engine | Yes | Partial | CUDA features may be limited on arm64 |
| All other pip packages | Yes | Yes | |

### System Packages

| Package Category | amd64 | arm64 | Notes |
|------------------|:-----:|:-----:|-------|
| Core CLI tools | Yes | Yes | git-lfs, ripgrep, fzf, etc. |
| GPU monitoring | Yes | Partial | nvtop may not be available on arm64 |
| Build tools | Yes | Yes | cmake, clang, meson, etc. |
| OpenCV/OpenMPI | Yes | Yes | |
| Fun tools | Yes | Partial | Some X11-dependent tools may be unavailable |

### Packages Skipped on Certain Architectures

The Dockerfile automatically detects and skips packages unavailable for the target architecture. During build, you'll see output like:

```
Skipped (arch/unavailable): <package-list>
```

Common packages that may be skipped on arm64:
- `nvtop` - GPU monitoring (may not have arm64 package)
- `xcowsay`, `oneko` - X11-dependent fun tools
- Some architecture-specific dev libraries

## Installed Tooling

### GPU & Profiling

- **Monitoring**: `nvtop`, `nvitop` (pip), `nvidia-smi` (base image)
- **Profiling**: `torch-tb-profiler` (pip), `accelerate` (pip)
- **System**: `btop`, `htop`, `glances`, `powertop`, `powerstat`
- **Storage**: `iotop`, `smartmontools`, `nvme-cli`
- **Network**: `iftop`, `nethogs`, `ifstat`

### Development

- **Build**: `cmake`, `meson`, `ccache`, `ninja-build` (base)
- **Compilers**: `clang`, `clang-format`, `clang-tidy`, `lld`, `lldb`
- **Debug**: `gdb` (base), `valgrind` (base), `strace`, `ltrace`
- **VCS**: `git` (base), `git-lfs`, `mercurial`, `subversion`

### CLI Productivity

- **Search**: `ripgrep`, `fd-find` (aliased to `fd`), `fzf`, `plocate`
- **Files**: `bat` (aliased), `tree`, `ncdu`, `gdu`, `fdupes`
- **Text**: `jq` (base), `yq`, `moreutils`, `rename`
- **Archive**: `p7zip-full`, `zstd`, `pigz`, `pbzip2`, `unar`
- **Network**: `mtr`, `nmap`, `traceroute`, `tcpdump`, `autossh`

### Python Environment

The virtualenv at `/opt/nanugpt-venv` includes:

- **ML/DL**: transformers, datasets, accelerate, deepspeed, lightning, peft, trl
- **Eval**: lm-eval, evaluate, math-verify
- **Data**: numpy, pandas, scipy, pyarrow, orjson
- **Viz**: matplotlib, tensorboard, wandb, mlflow
- **Tokenizers**: tiktoken, sentencepiece, tokenizers
- **Cloud**: azure-identity, azure-storage-blob, huggingface-hub
- **Utils**: rich, tqdm, typer, omegaconf, tenacity

## What's Already in the Base Image

The NVIDIA PyTorch 25.11 base image includes (not reinstalled):

- `git`, `curl`, `wget`, `tar`, `xz-utils`, `bash-completion`
- `build-essential`, `g++`, `gcc`, `pkg-config`, `ninja-build`
- `autoconf`, `automake`, `libtool`, `gdb`, `valgrind`
- `tmux`, `jq`, `watch`, `zip`, `unzip`
- `openssh-client`, `nfs-common`, `numactl`
- NVIDIA tooling: `nvidia-smi`, CUDA compilers, NCCL, cuDNN

## Intentionally Excluded

| Item | Reason |
|------|--------|
| `tlp`, `tlp-rdw` | Require systemd; don't work in containers |
| `linux-tools-generic` | Kernel-version specific; install on host instead |
| `perf` | Part of linux-tools; use host's version |

## nanuGPT Integration

The container is pre-configured for [nanuGPT](https://github.com/sytelus/nanuGPT):

```bash
# Inside the container
git clone https://github.com/sytelus/nanuGPT.git
cd nanuGPT
pip install -e .
```

- Python deps mirror nanuGPT's `pyproject.toml`
- CUDA/PyTorch from NVIDIA base remain untouched
- `flash-attn` pre-installed on amd64 (skipped on arm64)
- Interactive shells auto-activate the venv

## Verification

```bash
# Check GPU access
./run.sh -c "nvidia-smi"

# Verify Python environment
./run.sh -c "python -c 'import torch; print(torch.cuda.is_available())'"

# Check flash-attn (amd64 only)
./run.sh -c "python -c 'import flash_attn; print(\"flash-attn OK\")'"

# Verify multi-arch manifest after push
./verify.sh sytelus/gpu-devbox:latest
```

## Troubleshooting

### "no match for platform"
Run `./setup-builder.sh` to create/activate the buildx builder with QEMU.

### GPU not detected
- Ensure NVIDIA Container Toolkit is installed: `nvidia-container-cli info`
- Run with `--gpus all`: `./run.sh` does this automatically

### flash-attn build failures
- Only pre-installed on amd64
- On arm64: source build requires excessive time/memory; skipped by default
- To build manually: ensure adequate RAM (16GB+) and run `pip install flash-attn --no-build-isolation`

### Slow arm64 builds
- Cross-compilation via QEMU is slow (~10x native)
- Use a native arm64 runner for faster builds
- Consider `PLATFORMS=linux/amd64` for amd64-only builds

### Container health check failing
- The container includes a health check that verifies PyTorch is importable
- Check with: `docker inspect --format='{{.State.Health.Status}}' <container>`

## CI/CD Integration

```bash
# Build and push in CI (skip interactive login)
SKIP_LOGIN=1 ./push_multiarch.sh

# Or use GitHub Actions with docker/login-action first
```

## Extending the Image

```dockerfile
FROM sytelus/gpu-devbox:latest

# Add your packages
RUN pip install your-package

# Or add system packages
RUN apt-get update && apt-get install -y your-package && rm -rf /var/lib/apt/lists/*
```

## License

MIT - See repository root for details.
