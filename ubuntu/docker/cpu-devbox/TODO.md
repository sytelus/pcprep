# CPU Devbox - Future Improvements

This document contains suggested improvements that require review and approval before implementation.


## Approved

(No pending approved items - all have been implemented)


## Future Considerations

These items may be worth implementing when conditions change.

### 1. Add ARM64 Native Build Script

**Description**: Create `build_arm64_native.sh` for building on native ARM64 hardware (10x faster than QEMU emulation).

**Current State**: ARM64 builds use QEMU emulation which is slow.

**Potential Approach**: Similar to gpu-devbox's `build_arm64_native.sh` script.

**Trigger**: When ARM64 builds become frequent enough to justify dedicated hardware.

---

### 2. Add Oh My Zsh Integration

**Description**: Pre-install Oh My Zsh for enhanced Zsh experience, similar to gpu-devbox.

**Current State**: Zsh is installed but Oh My Zsh is not configured.

**Trade-offs**:
- Adds ~50MB to image size
- Not all users want Zsh customizations

**Recommendation**: Keep optional; users can install manually if needed.

---

### 3. Add Helm Support

**Description**: Re-enable Helm installation (currently commented out to reduce image size).

**Current State**: kubectl is installed, but Helm is disabled.

**Implementation**: Uncomment the Helm installation block in Dockerfile.

**Trade-offs**: Adds ~50MB to image size.

---

### 4. Extract Common Build Script Functions

**Description**: Build scripts share duplicated code for Dockerfile path resolution, VCS_REF, etc.

**Current State**: Each script has similar ~15 lines for setup.

**Potential Approach**: Create `_build_common.sh` that exports common variables/functions.

**Why Not Done Now**: Adds indirection and complexity; current duplication is manageable.

---


## Risky

These items were considered but moved here due to potential for introducing bugs or unnecessary complexity.

### 5. Add Layer Caching Optimization

**Description**: Restructure Dockerfile to maximize layer cache reuse.

**Current State**: Single large RUN command for apt packages means any package change invalidates the entire layer.

**Why Risky**:
- Restructuring the Dockerfile layers could break the build process
- More layers can actually increase image size due to layer overhead
- The current approach is simpler and well-tested

---


## Do NOT Implement

### Pin All Python Package Versions

**Reason**: Creates maintenance burden and prevents security updates. Use minimum versions (`>=`) instead.

---


## Completed Improvements

### Initial Setup (December 2025)

- [x] **Fixed heredoc syntax** - Changed from shell heredoc inside RUN to Dockerfile heredoc syntax (`RUN <<'EOF'`) with different inner delimiter (`<<'EOS'`) to fix parse error
- [x] **Added build logging** - Build output now saved to timestamped log files in `logs/` directory
- [x] **Added VCS_REF support** - All build scripts now pass git commit SHA to Docker build for image labeling
- [x] **Improved run.sh** - Added support for volume mounts, port exposure, and custom commands
- [x] **Added SKIP_LOGIN** - push_multiarch.sh now supports `SKIP_LOGIN=1` for CI environments
- [x] **Added HEALTHCHECK** - Dockerfile now includes health check to verify Python is functional
- [x] **Added --provenance and --sbom** - Multi-arch builds now include SLSA provenance and SBOM
- [x] **Simplified path resolution** - Use realpath with Python fallback instead of complex Python heredoc

---

## How to Propose Changes

1. Open an issue describing the improvement
2. Reference the item number from this document
3. Discuss implementation approach
4. Submit PR with changes
