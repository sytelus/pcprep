# GPU Devbox - Future Improvements

This document contains suggested improvements that require review and approval before implementation.


## High Priority

### 4. Add Nsight Systems/Compute Support

**Description**: Include NVIDIA Nsight profiling tools when available for the architecture.

**Current State**: Not included because NVIDIA doesn't publish multi-arch packages.

**Benefits**:
- Deep GPU kernel profiling
- Memory access pattern analysis
- Performance bottleneck identification

**Implementation Notes**:
- Monitor NVIDIA's package repository for arm64 support
- Could add as amd64-only conditional install

**Estimated Effort**: 1 hour (when packages become available)

---

### 5. Add Dev Container Support

**Description**: Create `.devcontainer/devcontainer.json` for VS Code Remote Containers / GitHub Codespaces.

**Benefits**:
- One-click development environment setup
- Consistent dev environment across team
- Works with GitHub Codespaces

**Implementation Notes**:
```json
{
  "name": "GPU Devbox",
  "image": "sytelus/gpu-devbox:latest",
  "runArgs": ["--gpus", "all"],
  "customizations": {
    "vscode": {
      "extensions": ["ms-python.python", "ms-toolsai.jupyter"]
    }
  }
}
```

**Estimated Effort**: 1-2 hours

---

### 6. Add Layer Caching Optimization

**Description**: Restructure Dockerfile to maximize layer cache reuse.

**Current State**: Single large RUN command for apt packages means any package change invalidates the entire layer.

**Potential Approach**:
- Split into: base tools → dev tools → fun tools → Python packages
- Use `--mount=type=cache` for apt lists

**Trade-offs**:
- More layers = slightly larger image
- More complex Dockerfile

**Estimated Effort**: 2-3 hours

---

### 8. Add ARM64 Native Build Support

**Description**: Document or script building on native ARM64 hardware (e.g., AWS Graviton, Apple Silicon).

**Benefits**:
- 10x faster ARM64 builds vs QEMU emulation
- Required for flash-attn on ARM64 (if ever needed)

**Implementation Notes**:
- Could use GitHub's arm64 runners (when available)
- Or document self-hosted runner setup

**Estimated Effort**: 2-3 hours

---

### 9. Add Image Size Optimization

**Description**: Analyze and reduce image size.

**Current State**: Image likely 15-20GB+ due to NVIDIA base + all packages.

**Potential Optimizations**:
- Multi-stage build to exclude build-only dependencies
- Remove apt cache more aggressively
- Evaluate which "fun" packages are actually used

**Trade-offs**:
- Smaller image vs. having all tools available
- May complicate Dockerfile

**Estimated Effort**: 3-4 hours

---



### 11. Add Shell Configuration Options

**Description**: Support Zsh with Oh My Zsh as an alternative shell.

**Current State**: Bash only with custom aliases.

**Benefits**:
- Better autocomplete
- Popular among developers
- Plugin ecosystem

**Trade-offs**:
- Larger image
- More configuration to maintain

**Estimated Effort**: 1-2 hours

---



## Do NOT Implement

### 1. Add GitHub Actions CI/CD Pipeline

**Description**: Create a `.github/workflows/docker-build.yml` to automate multi-arch builds and pushes on release tags.

**Benefits**:
- Automated builds on push/release
- Consistent build environment
- Automatic vulnerability scanning via GitHub's container scanning

**Implementation Notes**:
```yaml
# Suggested workflow structure
on:
  push:
    tags: ['v*']
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
      - uses: docker/build-push-action@v5
```

**Estimated Effort**: 2-3 hours

---

### 2. Add Container Security Scanning

**Description**: Integrate Trivy or Snyk for vulnerability scanning during builds.

**Benefits**:
- Identify CVEs in base image and installed packages
- Block builds with critical vulnerabilities
- Security compliance reporting

**Implementation Notes**:
- Can use `aquasecurity/trivy-action` in GitHub Actions
- Or add `trivy image --exit-code 1 --severity CRITICAL` to build scripts

**Estimated Effort**: 1-2 hours

---

### 3. Pin Python Package Versions

**Description**: Create a `requirements.txt` or `requirements.lock` with pinned versions for reproducible builds.

**Current State**: Most packages use latest versions which can cause build failures when upstream releases break.

**Benefits**:
- Reproducible builds
- Prevent unexpected breakages from upstream updates
- Easier debugging of version conflicts

**Trade-offs**:
- Requires periodic updates to get new features/fixes
- May miss security patches if not updated regularly

**Estimated Effort**: 2-3 hours (initial) + ongoing maintenance

---

### 12. Add Jupyter Lab Integration

**Description**: Pre-install and configure Jupyter Lab with GPU-aware kernels.

**Benefits**:
- Interactive notebook development
- Visualization support
- Common ML workflow

**Implementation Notes**:
- Install jupyterlab, ipywidgets
- Configure for remote access
- Add to run.sh as optional service mode

**Estimated Effort**: 2-3 hours

---

### 10. Add Automatic Base Image Updates

**Description**: Create workflow to detect and test new NVIDIA base image releases.

**Benefits**:
- Stay current with CUDA/PyTorch updates
- Get security patches faster
- Automated testing before adoption

**Implementation Notes**:
- Use Dependabot for Dockerfile or custom workflow
- Run basic smoke tests before merging

**Estimated Effort**: 3-4 hours

---

### 7. Add Compose File for Multi-Container Setups

**Description**: Create `docker-compose.yml` for common development scenarios.

**Use Cases**:
- GPU devbox + Redis for distributed training
- GPU devbox + TensorBoard service
- GPU devbox + Jupyter Lab exposed

**Example**:
```yaml
services:
  devbox:
    image: sytelus/gpu-devbox:latest
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
  tensorboard:
    image: tensorflow/tensorflow
    command: tensorboard --logdir=/logs --bind_all
    ports: ["6006:6006"]
```

**Estimated Effort**: 1-2 hours

---


## Completed Improvements

- [x] Optimized apt-cache package availability check (batched instead of per-package)
- [x] Fixed plocate database generation (use updatedb instead of incorrect plocate-build syntax)
- [x] Fixed flash-attn installation logic (simplified to latest version only)
- [x] Combined RUN chmod commands with heredocs (reduced layers)
- [x] Added HEALTHCHECK to Dockerfile
- [x] Improved run.sh to handle no-GPU scenarios gracefully
- [x] Added VCS_REF to all build scripts for image labeling
- [x] Simplified relative path calculation (use realpath with Python fallback)
- [x] Improved error handling in docker_info.sh
- [x] Enhanced verify.sh with platform and label inspection
- [x] Added SKIP_LOGIN option to push_multiarch.sh for CI
- [x] Updated README.md with architecture-specific availability tables
- [x] Added comprehensive environment variable documentation

---

## How to Propose Changes

1. Open an issue describing the improvement
2. Reference the item number from this document
3. Discuss implementation approach
4. Submit PR with changes
