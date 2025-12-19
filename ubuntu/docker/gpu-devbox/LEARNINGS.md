# GPU Devbox - Learnings

This document captures lessons learned from building and maintaining the GPU devbox container image. These insights help avoid repeating mistakes and inform future development decisions.

---

## Pip and Python Package Management

### 1. Pip Resolver Backtracking Can Take Hours

**Problem:** When pip cannot find a compatible version of a package, it backtracks through every available version. For packages with many releases (like lm-eval with 20+ versions), this can take an extremely long time.

**Real Example:** lm-eval installation took **29+ hours on arm64** and ~19 minutes on amd64 before ultimately failing. Pip tried versions 0.4.9.2 → 0.4.8 → 0.4.7 → ... → 0.0.1.

**Solution:** Wrap pip install commands for packages with known dependency issues in a `timeout` command:
```bash
timeout 300 pip install package-name  # 5 minute limit
```

**Date:** December 2025

---

### 2. datasets 4.x Breaks lm-eval Compatibility

**Problem:** The NVIDIA PyTorch 25.11 base image ships with `datasets==4.4.1`, but lm-eval requires `datasets<4.0, >=2.16.0`. No version of lm-eval is compatible.

**Conflict Details:**
```
lm-eval 0.4.9.1 depends on datasets<4.0 and >=2.16.0
The user requested (constraint) datasets==4.4.1
```

**Resolution:** Keep lm-eval in the optional packages list with timeout, and wait for lm-eval to release a datasets 4.x compatible version.

**Date:** December 2025

---

### 3. PIP_NO_CACHE_DIR Disables Cache Mounts

**Problem:** Setting `PIP_NO_CACHE_DIR=1` in the Dockerfile's ENV block completely disables pip caching, including the `--mount=type=cache,target=/root/.cache/pip` optimization.

**Symptom:** Build times don't improve on subsequent builds despite using cache mounts.

**Solution:** Remove `PIP_NO_CACHE_DIR=1` from ENV. The `--no-cache-dir` flag can still be used on individual pip commands where needed.

**Date:** December 2025

---

### 4. Constraint Files Prevent Base Image Downgrades

**Problem:** Installing new packages can silently downgrade NVIDIA-optimized packages (torch, numpy, etc.), breaking GPU functionality.

**Solution:** Generate a constraints file from the base image at build time:
```bash
pip freeze | grep -v -E '@ |^-e |^file:|^\.' > /opt/base-image-constraints.txt
pip install --constraint /opt/base-image-constraints.txt new-package
```

This prevents pip from downgrading any package that was in the base image.

**Date:** December 2025

---

### 5. Use --no-build-isolation for Packages Requiring torch

**Problem:** Packages like `torchao` and `flash-attn` need access to the existing torch installation during their build process. Standard pip isolation prevents this.

**Solution:** Use `--no-build-isolation` flag:
```bash
pip install torchao --no-build-isolation
pip install flash-attn --no-build-isolation
```

**Date:** December 2025

---

## Docker and Buildx

### 6. --load and --push Cannot Be Used Together

**Problem:** In Docker buildx, the `--load` flag (load into local Docker) and `--push` flag (push to registry) are mutually exclusive for multi-platform builds.

**Symptom:** Build fails with error about incompatible output options.

**Solution:** Use one or the other based on intent:
```bash
# For local testing
docker buildx build --load ...

# For pushing to registry
docker buildx build --push ...
```

**Date:** December 2025

---

### 7. Multi-arch Images Can't Be Loaded Locally

**Problem:** When building for multiple platforms (e.g., `linux/amd64,linux/arm64`), the resulting manifest can't be loaded into local Docker because it contains images for architectures the host can't run.

**Solution:**
- Use `--load` only with single-platform builds (build_local.sh)
- For multi-arch, cache to buildx cache and push directly to registry
- Test locally with single-arch build before multi-arch push

**Date:** December 2025

---

### 8. QEMU Emulation is ~10x Slower

**Problem:** Cross-architecture builds using QEMU (e.g., building arm64 on amd64) are approximately 10x slower than native builds.

**Real Example:** arm64 build took ~30 hours via QEMU vs ~3 hours natively.

**Solution:**
- For production builds, use native arm64 hardware (Apple Silicon, AWS Graviton, etc.)
- Use `build_arm64_native.sh` script on ARM64 machines
- Only use QEMU for quick cross-arch smoke tests

**Date:** December 2025

---

## Container Design Philosophy

### 9. No Virtual Environment Needed in Containers

**Problem:** Adding a virtual environment inside a container adds complexity without benefit. The container itself provides isolation.

**Anti-pattern:**
```dockerfile
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
```

**Better approach:** Install packages directly into the system Python. The container IS the environment.

**Benefits:**
- Simpler mental model
- No activation required
- Container starts exactly like the base image

**Date:** December 2025

---

### 10. Make Conflicting Packages Optional with Build Args

**Problem:** Some packages (vllm, lm-eval) have strict version requirements that conflict with the base image.

**Solution:** Use build arguments to make installation optional:
```dockerfile
ARG INSTALL_VLLM="false"
RUN if [ "${INSTALL_VLLM}" = "true" ]; then \
      pip install vllm || echo "WARNING: vllm installation failed"; \
    fi
```

**Benefits:**
- Default build succeeds
- Users can opt-in when they need the package
- Easy to flip default when upstream fixes compatibility

**Date:** December 2025

---

### 11. Prefer >= Over == for Version Constraints

**Problem:** Pinning exact versions (`==`) prevents security updates and creates maintenance burden.

**Better approach:** Use minimum versions (`>=`) unless a specific version is required:
```
transformers>=4.30.0  # Good - allows updates
transformers==4.30.0  # Avoid - blocks updates
```

**Exception:** Pin versions only when resolving a specific known conflict.

**Date:** December 2025

---

## Build Script Patterns

### 12. Use pipefail in Dockerfile SHELL

**Problem:** In pipelines, bash returns the exit code of the last command, hiding failures in earlier commands.

**Example of hidden failure:**
```bash
failing-command | tee log.txt  # Returns 0 because tee succeeds
```

**Solution:** Set pipefail in the SHELL directive:
```dockerfile
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
```

Now the pipeline returns the exit code of the first failing command.

**Date:** December 2025

---

### 13. Architecture Detection for Conditional Installation

**Problem:** Some packages only have wheels for certain architectures (flash-attn is amd64-only).

**Solution:** Use TARGETARCH build argument:
```dockerfile
ARG TARGETARCH
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
      pip install flash-attn; \
    elif [ "${TARGETARCH}" = "arm64" ]; then \
      echo "Skipping flash-attn on arm64"; \
    fi
```

**Date:** December 2025

---

### 14. Skip Unavailable apt Packages Gracefully

**Problem:** Some apt packages aren't available on all architectures (nvtop, nsight-systems-cli), causing build failures.

**Solution:** Check package availability before installing:
```bash
AVAILABLE_PKGS=$(apt-cache show $PKGS 2>/dev/null | grep '^Package:' | awk '{print $2}')
for pkg in $PKGS; do
  if echo "$AVAILABLE_PKGS" | grep -qx "$pkg"; then
    INSTALLABLE="$INSTALLABLE $pkg"
  else
    SKIPPED="$SKIPPED $pkg"
  fi
done
apt-get install -y $INSTALLABLE
echo "Skipped: $SKIPPED"
```

**Date:** December 2025

---

## Debugging and Logging

### 15. Always Log Build Output to Files

**Problem:** Long builds produce thousands of lines of output. Finding errors requires scrolling through everything.

**Solution:** Tee output to timestamped log files:
```bash
LOG_FILE="logs/build_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1
```

**Benefits:**
- Searchable after the fact
- Can grep for errors: `grep -i error build.log`
- Preserves full context for debugging

**Date:** December 2025

---

## Future Considerations

### Packages to Re-test with New Base Images

When NVIDIA releases new PyTorch containers, test these packages:

| Package | Current Issue | What to Test |
|---------|--------------|--------------|
| lm-eval | Requires datasets<4.0 | `pip install lm-eval` - check if compatible with new datasets version |
| vllm | Strict torch requirements | `pip install vllm` - check if torch version matches |
| flash-attn (arm64) | No prebuilt wheels | Check if arm64 wheels are released |

---

## Environment Variables and Base Image Quirks

### 16. NVIDIA Base Image PS1 Unbound Variable Error

**Problem:** NVIDIA PyTorch base images have `/etc/bash.bashrc` with `set -u` (nounset) that references `PS1` before it's defined. During non-interactive RUN commands, `PS1` isn't set, causing:
```
/etc/bash.bashrc: line 9: PS1: unbound variable
```

**Solution:** Set a default `PS1` in the Dockerfile's ENV block before any RUN commands:
```dockerfile
ENV PS1='\\u@\\h:\\w\\$ '
```

**Why it works:** The ENV sets `PS1` globally, so when `/etc/bash.bashrc` runs during RUN commands, the variable exists.

**Date:** December 2025

---

### 17. Pip PIP_CONSTRAINT Deprecation Warning

**Problem:** Starting with pip 26.2, the `--constraint` flag will no longer affect build-time dependencies. This causes a deprecation warning:
```
DEPRECATION: Setting PIP_CONSTRAINT will not affect build constraints in the future...
```

**Solution:** Set the feature flag to opt-in to the new behavior early and silence the warning:
```dockerfile
ENV PIP_USE_FEATURE=build-constraint
```

**Why it works:** This tells pip you accept the new behavior where constraints only affect runtime dependencies, not build dependencies.

**Date:** December 2025

---

## Contributing

When you discover a new learning:
1. Add it to this document with a clear problem/solution format
2. Include the date for context
3. Add real examples where possible
4. Update the Table of Contents if adding new sections
