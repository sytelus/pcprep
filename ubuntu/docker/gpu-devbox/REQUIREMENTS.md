# GPU Devbox Requirements

This document captures the design requirements and decisions for the GPU devbox container image.

## Core Philosophy

1. **Extend, don't replace** - The container should be the NVIDIA base image with additional packages, not a separate environment layered on top.

2. **Simplicity over complexity** - Avoid wrappers, scripts, and mechanisms that add maintenance burden. If something can't be done simply, it's better to not do it.

3. **Development flexibility** - Developers should be able to `pip install` additional packages freely. No pinning or constraints that prevent upgrades.

4. **Base image integrity** - Packages from the NVIDIA base image (torch, numpy, scipy, CUDA libraries, etc.) should never be downgraded.

5. **Disable Additional Installs If Needed** - if there are conflicts with base image for any additional packages then make that package optional and disable its install by default.

## Package Management

### No Virtual Environment

- Packages install directly into the base image's Python (`/usr/local/lib/python3.12/dist-packages`)
- No venv activation required - container starts exactly like the base image
- Simpler mental model: the container IS the environment

### Preventing Package Downgrades

- At build time, `pip freeze` captures all packages from the NVIDIA base image
- The output is saved to `/opt/base-image-constraints.txt`
- All pip installs use `--constraint /opt/base-image-constraints.txt`
- This prevents pip from downgrading any base image package
- If a new package requires a conflicting version, pip fails with a clear error rather than silently breaking things

### Version Specifications

- **Prefer `>=` over `==`** - Use minimum version constraints, not pinned versions
- This allows security updates and improvements while preventing known-bad versions
- Only pin versions when absolutely necessary to resolve a specific conflict

### Handling Conflicts

When a package has version conflicts with the base image:

1. **Make it optional** - Add a build arg (default: `false`) to control installation
2. **Document the conflict** - Note why it's disabled in comments and documentation
3. **Re-enable when resolved** - When newer base images fix the conflict, flip the default

Current optional packages:
- `vllm` - Has strict torch version requirements that conflict with NVIDIA's torch build

## What Should NOT Be Done

### No pip wrappers
- Don't create wrapper scripts around pip to detect/prevent uninstalls
- Too complex, fragile, and hard to maintain

### No strict version pinning
- Don't pin all packages to exact versions
- Prevents developers from upgrading packages they need
- Creates maintenance burden keeping pins up to date

### No separate Python environment
- Don't create a venv just to "isolate" from base image
- The container itself provides isolation
- Adding a venv adds complexity without benefit

## Build Arguments

| Argument | Default | Purpose |
|----------|---------|---------|
| `INSTALL_VLLM` | `false` | Enable vllm installation (may conflict with base image torch) |

## Container Startup

When the container starts:
- No environment activation needed
- Python is the system Python with all packages available
- Shell greeting displays system info (can be customized or disabled)
- `/root/.local/bin` is added to PATH for user-installed tools

## Future Considerations

1. **New base images** - When NVIDIA releases new PyTorch containers, re-test optional packages and enable them if conflicts are resolved

2. **New conflicting packages** - If new packages cause conflicts, follow the "make it optional" pattern rather than complex workarounds

3. **Constraint file location** - The constraints file at `/opt/base-image-constraints.txt` can be used by developers to understand what's locked down
