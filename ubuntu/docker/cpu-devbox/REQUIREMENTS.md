# CPU Devbox Requirements

This document captures the design requirements and decisions for the CPU devbox container image.

## Core Philosophy

1. **Multi-architecture support** - The container should build and run on both amd64 (x86_64) and arm64 (Apple Silicon, AWS Graviton, etc.).

2. **Graceful degradation** - If a package isn't available for an architecture, skip it with a warning rather than failing the build.

3. **Conda-based Python environment** - Use Miniconda/Miniforge for Python package management, providing conda-forge access for scientific packages.

4. **Development flexibility** - Developers should be able to install additional packages freely via conda or pip.

5. **Terminal-first** - Optimized for CLI/terminal usage with rich tooling, not GUI applications.

## Package Management

### Conda Environment

- Uses Miniforge (conda-forge by default) for better cross-platform support
- Base environment is auto-activated in interactive shells
- Python packages install into the base conda environment
- Channel priority: `conda-forge` (strict)

### System Packages (apt)

- Packages are installed via apt with graceful fallback
- Unavailable packages on specific architectures are logged and skipped
- `--no-install-recommends` used to minimize image size

### Handling Architecture Differences

When a package isn't available for an architecture:

1. **Log the skip** - Output a message showing what was skipped and why
2. **Continue the build** - Don't fail the entire build for optional packages
3. **Document in README** - Note architecture-specific availability

Current architecture-specific packages:
- `AzCopy` - Available for amd64 and arm64 (different download URLs)
- `nsight-*` - Not available on arm64 (GPU profiling tools)
- `linux-tools-generic` - Kernel-version specific, may not be available

## What Should NOT Be Done

### No heavy GUI dependencies
- Don't install X11 server components
- Don't install full desktop environments
- Lightweight X11 client libraries are OK for clipboard tools

### No systemd-dependent tools
- `tlp`, `tlp-rdw` require systemd and don't work in containers
- Use alternatives or skip these tools

### No kernel-specific packages
- `linux-tools-generic` depends on kernel version
- `perf` should be used from the host

## Build Arguments

| Argument | Default | Purpose |
|----------|---------|---------|
| `VCS_REF` | Git HEAD | Version control reference for image labels |

## Container Startup

When the container starts:
- Conda base environment is auto-activated
- Greeting banner displays system info and tool versions
- `/root/.local/bin` is available in PATH
- Bash is the default shell (Zsh available via `zsh` command)

## Included Tool Categories

### Cloud & DevOps
- Azure CLI, AzCopy
- GitHub CLI (gh)
- kubectl (Kubernetes)
- rclone (cloud storage)

### Development
- Git, Git LFS, Mercurial, Subversion
- Build tools: cmake, meson, ninja, ccache
- Compilers: gcc, g++, clang, clang-format, clang-tidy
- Debuggers: gdb, lldb, valgrind, strace, ltrace

### CLI Productivity
- Search: ripgrep, fd-find, fzf, plocate
- Files: bat, tree, ncdu, gdu
- Text: jq, yq, moreutils
- Archive: p7zip, zstd, pigz, pbzip2

### Python/ML Stack
- PyTorch, TensorFlow (CPU versions)
- transformers, datasets, accelerate
- scikit-learn, pandas, matplotlib
- Jupyter, tensorboard, wandb

## Future Considerations

1. **GPU variant** - Consider creating a GPU-enabled variant based on NVIDIA containers (see gpu-devbox)

2. **Slim variant** - Consider a minimal variant without ML packages for faster pulls

3. **Version pinning** - Consider pinning critical package versions for reproducibility
