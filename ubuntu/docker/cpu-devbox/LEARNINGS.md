# CPU Devbox - Learnings

This document captures lessons learned from building and maintaining the CPU devbox container image. These insights help avoid repeating mistakes and inform future development decisions.

---

## Dockerfile Syntax

### 1. Dockerfile Heredoc vs Shell Heredoc

**Problem:** Using shell heredoc (`<<'EOF'`) inside a `RUN` command with backslash continuation causes the `chmod` command after the heredoc to be interpreted as a Dockerfile instruction instead of a shell command.

**Broken example:**
```dockerfile
RUN set -eux; \
    cat >/usr/local/bin/script <<'EOF'
#!/bin/bash
echo "Hello"
EOF
    chmod +x /usr/local/bin/script  # ERROR: Interpreted as Dockerfile instruction!
```

**Error message:**
```
unknown instruction: chmod (did you mean cmd?)
```

**Solution:** Use Dockerfile heredoc syntax (`RUN <<'EOF'`) with a different delimiter for the inner shell heredoc (`<<'EOS'`):

```dockerfile
RUN <<'EOF'
set -eux
cat >/usr/local/bin/script <<'EOS'
#!/bin/bash
echo "Hello"
EOS
chmod +x /usr/local/bin/script  # Now correctly inside the RUN
EOF
```

**Key insight:** When the outer `EOF` ends, the RUN command ends. The Dockerfile parser then sees `chmod` as the next instruction.

**Date:** December 2025

---

### 2. Use pipefail in Dockerfile SHELL

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

## Multi-Architecture Builds

### 3. QEMU Emulation is ~10x Slower

**Problem:** Cross-architecture builds using QEMU (e.g., building arm64 on amd64) are approximately 10x slower than native builds.

**Real Example:** arm64 build took ~8 hours via QEMU vs ~45 minutes natively.

**Solution:**
- For production builds, use native arm64 hardware (Apple Silicon, AWS Graviton, etc.)
- Only use QEMU for quick cross-arch smoke tests

**Date:** December 2025

---

### 4. Skip Unavailable apt Packages Gracefully

**Problem:** Some apt packages aren't available on all architectures, causing build failures.

**Solution:** Check package availability before installing:
```bash
AVAILABLE_PKGS=$(apt-cache show $PKGS 2>/dev/null | grep '^Package:' | awk '{print $2}')
for pkg in $PKGS; do
  if apt-cache show --no-all-versions "$pkg" >/dev/null 2>&1; then
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

### 5. Architecture Detection for Conditional Installation

**Problem:** Some tools only have binaries for certain architectures (e.g., AzCopy has different URLs for amd64 vs arm64).

**Solution:** Use TARGETARCH build argument:
```dockerfile
ARG TARGETARCH
RUN case "$TARGETARCH" in \
      amd64) URL="https://...linux";; \
      arm64) URL="https://...linux-arm64";; \
      *)     URL="";; \
    esac; \
    if [ -n "$URL" ]; then curl -fsSL "$URL" -o tool.tgz; fi
```

**Date:** December 2025

---

## Build Scripts

### 6. Use realpath with Python Fallback

**Problem:** macOS doesn't have GNU `realpath` by default, and the Python heredoc approach is overly complex.

**Solution:** Try realpath first, fall back to Python:
```bash
if command -v realpath >/dev/null 2>&1; then
    DOCKERFILE=$(realpath --relative-to="${BUILD_CONTEXT}" "${SCRIPT_DIR}/Dockerfile")
else
    DOCKERFILE=$(python3 -c "import os; print(os.path.relpath('${SCRIPT_DIR}/Dockerfile', '${BUILD_CONTEXT}'))")
fi
```

**Date:** December 2025

---

### 7. Always Log Build Output to Files

**Problem:** Long builds produce thousands of lines of output. Finding errors requires scrolling through everything.

**Solution:** Tee output to timestamped log files:
```bash
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/build_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1
```

**Benefits:**
- Searchable after the fact
- Can grep for errors: `grep -i error build.log`
- Preserves full context for debugging

**Date:** December 2025

---

### 8. Add VCS_REF for Image Traceability

**Problem:** Can't tell which git commit an image was built from.

**Solution:** Pass git SHA as build argument:
```bash
VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
docker buildx build --build-arg VCS_REF="${VCS_REF}" ...
```

And in Dockerfile:
```dockerfile
ARG VCS_REF
LABEL org.opencontainers.image.revision="${VCS_REF}"
```

**Date:** December 2025

---

## Conda/Python

### 9. Use Miniforge for Better Multi-Arch Support

**Problem:** Miniconda has historically had weaker arm64 support than conda-forge.

**Solution:** Use Miniforge which defaults to conda-forge channel:
```bash
case "$TARGETARCH" in
  amd64) CONDA_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh";;
  arm64) CONDA_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh";;
esac
```

**Benefits:**
- conda-forge has better arm64 package coverage
- Community-driven, more frequent updates
- Stricter channel priority by default

**Date:** December 2025

---

### 10. Conda vs Pip: When to Use Each

**Guideline:**
- **Conda first** for packages with C/C++ dependencies (numpy, scipy, pytorch, tensorflow)
- **Pip fallback** for Python-only packages not in conda-forge
- **Never mix** the same package from both (causes conflicts)

**Pattern in Dockerfile:**
```bash
for pkg in $PACKAGES; do
  if conda search -c conda-forge "$pkg" >/dev/null 2>&1; then
    conda install -y -c conda-forge "$pkg" || pip install "$pkg"
  else
    pip install "$pkg"
  fi
done
```

**Date:** December 2025

---

## Container Design

### 11. Auto-Activate Conda in Interactive Shells Only

**Problem:** Activating conda in non-interactive shells breaks some automation.

**Solution:** Only activate in interactive shells via `/etc/bash.bashrc`:
```bash
if [ -n "$PS1" ]; then
  if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    . "/opt/conda/etc/profile.d/conda.sh"
    conda activate base
  fi
fi
```

The `$PS1` check ensures this only runs in interactive sessions.

**Date:** December 2025

---

### 12. Use Login Shell for CMD

**Problem:** `/etc/bash.bashrc` (where conda activation lives) only runs for login shells.

**Solution:** Use `-l` flag in CMD:
```dockerfile
CMD ["/bin/bash", "-l"]
```

This ensures the bashrc runs and conda is activated when the container starts.

**Date:** December 2025

---

## Docker Buildx

### 13. --load and --push Cannot Be Used Together

**Problem:** In Docker buildx, the `--load` flag (load into local Docker) and `--push` flag (push to registry) are mutually exclusive for multi-platform builds.

**Solution:** Use one or the other based on intent:
```bash
# For local testing (single arch)
docker buildx build --load ...

# For pushing to registry (multi-arch)
docker buildx build --push ...
```

**Date:** December 2025

---

### 14. Multi-arch Images Can't Be Loaded Locally

**Problem:** When building for multiple platforms, the resulting manifest can't be loaded into local Docker.

**Solution:**
- Use `--load` only with single-platform builds (`build_local.sh`)
- For multi-arch, cache via buildx and push directly to registry
- Test locally with single-arch build before multi-arch push

**Date:** December 2025

---

## Contributing

When you discover a new learning:
1. Add it to this document with a clear problem/solution format
2. Include the date for context
3. Add real examples where possible
4. Update the Table of Contents if adding new sections
