# CPU Devbox (Ubuntu 24.04, multi-arch)

A terminal-first development box for **amd64**, **arm64**, and **arm/v7 (armhf)** with Azure CLI + AzCopy, Git + Git LFS + GitHub CLI, kubectl/Helm, zsh, micro, rusage, Miniconda (base auto-activated), and a broad toolbox.

- **Greeting on start:** prints `Welcome to CPU devbox!` plus CPU, RAM, kernel, and key tool versions.
- **Conda base** is auto-activated in interactive shells.
- **Packages from `tools.txt`** are included opportunistically per architecture. :contentReference[oaicite:1]{index=1}

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
# typically: docker run --rm -it <image:tag>
```

Build the image for **your current machine’s architecture** and load it into the classic Docker image store:

```bash
# IMAGE and TAG are optional here
IMAGE=cpu-devbox TAG=local build-local.sh
./run.sh                     # launches the image; you should see the welcome banner
```
## Platforms & architecture notes

* The scripts default to:
  `PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7`
  *`linux/arm/v7` corresponds to **armhf** (ARM 32‑bit hard-float).*
* Ubuntu 24.04 is multi-arch. Some third-party tools (e.g., AzCopy) are only published for certain arches. The Dockerfile **skips** unavailable items per-arch instead of failing the build, and logs what was skipped.

If you need to change platforms:

```bash
PLATFORMS=linux/amd64,linux/arm64 \
IMAGE=docker.io/<user>/cpu-devbox \
TAG=2025.09.13 \
./build-multiarch.sh
```

The multi-arch script uses a registry cache:

* `--cache-from type=registry,ref=$IMAGE:buildcache`
* `--cache-to   type=registry,ref=$IMAGE:buildcache,mode=max`

This dramatically speeds up subsequent builds on CI and on your workstation.

The multi-arch script enables:

* `--sbom=true`: attaches a Software Bill of Materials.
* `--provenance=true`: includes SLSA‑style provenance (BuildKit attestation).

You can inspect these with `docker buildx imagetools inspect <image:tag>` and compatible tooling.

## Troubleshooting

- **`no match for platform`**: Ensure the builder supports your requested platforms. Run `./setup-builder.sh` again.
- **Very slow emulated builds**: That’s expected under QEMU; prefer native runners (e.g., arm64 VM) or let CI produce that arch.
- **Azure CLI / AzCopy on arm/v7**: Not published by Microsoft for armhf; the Dockerfile will log a skip for that arch.
- **Conda heavy packages (TF/PT) on arm/v7**: Skipped if not available; the rest of Python stack still installs.
