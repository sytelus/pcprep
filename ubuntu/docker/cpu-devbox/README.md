# CPU Devbox (Ubuntu 24.04, multi-arch)

A terminal-first development box for **amd64** and **arm64** with Azure CLI + AzCopy, Git + Git LFS + GitHub CLI, kubectl, zsh, micro, Miniconda (base auto-activated), and a broad toolbox.

- **Greeting on start:** prints `Welcome to CPU devbox!` plus CPU, RAM, kernel, and key tool versions.
- **Conda base** is auto-activated in interactive shells.
- **Packages from `tools.txt`** are included opportunistically per architecture.

## Prerequisites

- Docker version **24+** with **Buildx** plugin (Docker Desktop and Ubuntu 24.04 has this by default).
- For Linux hosts planning to cross-build (e.g., build arm64 on an amd64 host): the scripts will install `binfmt` via the
  community image `tonistiigi/binfmt`. Requires a privileged container once.

```bash
bash ./docker_info.sh
 ```

## One-time setup

```bash
./setup-builder.sh
```

> **Note:** On Docker Desktop (Mac/Windows) the `binfmt` step is skipped, as Desktop already provides emulation for common architectures.

## Build, Run & push multi-arch

For multi-arch build:

```bash
bash build_multiarch.sh

# see instructions after build for running and pushing image
```

Build the image for **your current machine’s architecture** and load it into the classic Docker image store:

```bash
# IMAGE and TAG are optional here
IMAGE=cpu-devbox TAG=local ./build_local.sh
./run.sh                     # launches the image; you should see the welcome banner
```
## Platforms & architecture notes

* The scripts default to:
  `PLATFORMS=linux/amd64,linux/arm64`
* Ubuntu 24.04 is multi-arch. Some third-party tools (e.g., AzCopy) are only published for certain arches. The Dockerfile **skips** unavailable items per-arch instead of failing the build, and logs what was skipped.
* `build_multiarch.sh` keeps its cache under `.buildx-cache` (override with `CACHE_DIR`). Docker may warn that no output was specified—this is expected because the build is cached for a later `./push_multiarch.sh`.
* The helper scripts default the **build context** to the repo root so vendored dotfiles are available; override with `BUILD_CONTEXT=...` if you need something else.
* By default the scripts point at `ubuntu/docker/cpu-devbox/Dockerfile`; override with `DOCKERFILE=...` if you need a different Dockerfile.

If you need to change platforms:

```bash
PLATFORMS=linux/amd64 \
IMAGE=docker.io/<user>/cpu-devbox \
TAG=2025.09.13 \
./build_multiarch.sh
```

The multi-arch script enables:

* `--sbom=true`: attaches a Software Bill of Materials.
* `--provenance=true`: includes SLSA‑style provenance (BuildKit attestation).

You can inspect these with `docker buildx imagetools inspect <image:tag>` and compatible tooling.

## Troubleshooting

- **`no match for platform`**: Ensure the builder supports your requested platforms. Run `./setup-builder.sh` again.
- **Very slow emulated builds**: That’s expected under QEMU; prefer native runners (e.g., arm64 VM) or let CI produce that arch.
- **Azure CLI / AzCopy availability**: Microsoft currently publishes packages for amd64 and arm64. The Dockerfile logs a skip if a tool is missing for the active architecture.
- **Conda heavy packages (TF/PT)**: These install via conda-forge on amd64/arm64 when available; otherwise the build logs a skip.
- **SSH/GPG agent setup**: Inside the container we skip auto-starting host agents to avoid read-only filesystem errors. If you need an agent, start it manually once inside the devbox.

## Available Scripts

| Script | Description |
|--------|-------------|
| `setup-builder.sh` | One-time setup: creates a BuildKit builder with QEMU cross-arch support |
| `build_local.sh` | Builds image for the current host architecture and loads it locally |
| `build_multiarch.sh` | Builds multi-arch image (amd64 + arm64) without pushing; caches to `.buildx-cache` |
| `push_multiarch.sh` | Builds and pushes multi-arch image to Docker Hub |
| `run.sh` | Runs the locally-built image interactively |
| `verify.sh` | Inspects a pushed image's manifest (usage: `./verify.sh <image:tag>`) |
| `docker_info.sh` | Displays Docker version, disk usage, and BuildX info |
| `dockerprune.sh` | Prunes all unused Docker data (images, containers, volumes) — **destructive** |
| `docker-move-data.sh` | Moves Docker's data-root to a new location (e.g., larger disk) |

### Environment Variables

All build scripts support these overrides:

| Variable | Default | Description |
|----------|---------|-------------|
| `IMAGE` | `sytelus/cpu-devbox` or `cpu-devbox` | Image name |
| `TAG` | `YYYY.MM.DD` or `local` | Image tag |
| `PLATFORMS` | `linux/amd64,linux/arm64` | Target platforms (multi-arch only) |
| `BUILDER` | `cpu-devbox-builder` | BuildX builder name |
| `BUILD_CONTEXT` | Repository root | Docker build context directory |
| `DOCKERFILE` | Auto-detected | Path to Dockerfile relative to context |
| `CACHE_DIR` | `.buildx-cache` | Local cache directory (multi-arch only) |
