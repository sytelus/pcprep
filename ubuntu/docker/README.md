# CPU Devbox (Ubuntu 24.04, multi-arch)

A terminal-first development box for **amd64**, **arm64**, and **arm/v7 (armhf)** with Azure CLI + AzCopy, Git + Git LFS + GitHub CLI, kubectl/Helm, zsh, micro, rusage, Miniconda (base auto-activated), and a broad toolbox.

- **Greeting on start:** prints `Welcome to CPU devbox!` plus CPU, RAM, kernel, and key tool versions.
- **Conda base** is auto-activated in interactive shells.
- **Packages from `tools.txt`** are included opportunistically per architecture. :contentReference[oaicite:1]{index=1}

## 1) Prerequisites

- Docker **24+** with **Buildx** (Docker Desktop has this by default).
- For Linux hosts planning to cross-build (e.g., build arm64 on an amd64 host): the scripts will install `binfmt` via the
  community image `tonistiigi/binfmt`. Requires a privileged container once.

## 2) One-time setup

```bash
./setup-builder.sh
```

> **Note:** On Docker Desktop (Mac/Windows) the `binfmt` step is skipped, as Desktop already provides emulation for common architectures.

## 3) Build locally (single arch)

Build the image for **your current machine’s architecture** and load it into the classic Docker image store:

```bash
# IMAGE and TAG are optional here
IMAGE=cpu-devbox TAG=local build-local.sh
./run.sh                     # launches the image; you should see the welcome banner
```

## 4) Build & push multi-arch

You can push to **Docker Hub**, **GHCR**, or **Azure Container Registry**. Choose one of the flows below.

### A) Docker Hub

```bash
# Login once
docker login

export DOCKER_USER=$(jq -r '.auths | keys[0]' ~/.docker/config.json | cut -d/ -f1)

# Build & push
IMAGE=docker.io/${DOCKER_USER}/cpu-devbox \
TAG=latest \
./build-multiarch.sh

# Verify the manifest
./verify.sh docker.io/${DOCKER_USER}/cpu-devbox:latest
```

### B) GitHub Container Registry (GHCR)

```bash
# Create a PAT with 'read:packages' and 'write:packages' (and 'delete:packages' if desired).
echo $GHCR_PAT | docker login ghcr.io -u <your-github-username> --password-stdin

IMAGE=ghcr.io/<your-org-or-user>/cpu-devbox \
TAG=latest \
./build-multiarch.sh

./verify.sh ghcr.io/<your-org-or-user>/cpu-devbox:latest
```

### C) Azure Container Registry (ACR)

```bash
# Login via Azure CLI
az login                     # or ensure your session is active
az acr login -n <your-acr-name>  # registry FQDN will be <your-acr-name>.azurecr.io

IMAGE=<your-acr-name>.azurecr.io/cpu-devbox \
TAG=latest \
./build-multiarch.sh

./verify.sh <your-acr-name>.azurecr.io/cpu-devbox:latest
```

## 5) Platforms & architecture notes

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

## 6) Run the image

```bash
docker run --rm -it <image:tag>
# Example:
# docker run --rm -it ghcr.io/<user>/cpu-devbox:latest
#
# You should see:
#   Welcome to CPU devbox!
#   Host: ... | Arch: ... | Kernel: ... | Cores: N | RAM: X.YG
#
# Conda base environment will be active.
```

## 10) Troubleshooting

* **`no match for platform`**: Ensure the builder supports your requested platforms. Run `./setup-builder.sh` again.
* **Very slow emulated builds**: That’s expected under QEMU; prefer native runners (e.g., arm64 VM) or let CI produce that arch.
* **Azure CLI / AzCopy on arm/v7**: Not published by Microsoft for armhf; the Dockerfile will log a skip for that arch.
* **Conda heavy packages (TF/PT) on arm/v7**: Skipped if not available; the rest of Python stack still installs.

---

## TL;DR

```bash
# one-time
./setup-builder.sh

# Docker Hub example
docker login
IMAGE=docker.io/<user>/cpu-devbox TAG=latest ./build-multiarch.sh
./verify.sh docker.io/<user>/cpu-devbox:latest
docker run --rm -it docker.io/<user>/cpu-devbox:latest
```

