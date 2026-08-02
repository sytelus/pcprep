# pcprep

`pcprep` is a personal, opinionated collection of workstation bootstrap scripts,
development-container definitions, diagnostics, and maintenance utilities for
Windows, macOS, Ubuntu, and WSL.

> [!CAUTION]
> These scripts change package installations, user configuration, operating-system
> settings, and—in a few cases—stored data. Safety defects found in the initial
> review were remediated, but privileged/native integration has not been completed
> on every platform. Read [TODO.md](TODO.md) and
> [Security and safety](docs/SECURITY_AND_SAFETY.md) before running a script.

## Supported entry points

| Environment | Main entry point | Platform documentation | Current state |
| --- | --- | --- | --- |
| Windows 11 | `windows/prepare_new_box.ps1` | [Windows setup](windows/README.md) | Coherent orchestrated setup; review its confirmation and security notes first |
| macOS | `mac/prepare_new_box.sh` | [macOS setup](mac/README.md) | Coherent orchestrated setup with many opt-out environment variables |
| Ubuntu / WSL | `ubuntu/prepare_new_box.sh` | [Ubuntu and WSL](docs/UBUNTU.md) | Orchestrated flow plus separately documented specialist/legacy helpers |
| CPU containers | `ubuntu/docker/cpu-devbox/` | [CPU devbox](ubuntu/docker/cpu-devbox/README.md) | Build and run scripts for an Ubuntu/Miniforge image |
| NVIDIA GPU containers | `ubuntu/docker/gpu-devbox/` | [GPU devbox](ubuntu/docker/gpu-devbox/README.md) | NGC-based image; requires an NVIDIA-capable runtime |

Run platform setup from its own directory. Do not run scripts from
`archived/`; they are retained only as historical references.

## Start here

1. Read the platform-specific README above.
2. Review the [remaining and explicitly deferred issues](TODO.md).
3. Inspect the exact script and its downloaded dependencies before allowing it
   to change a machine.
4. Back up user configuration and data that the script may replace or delete.
5. Prefer an isolated test machine or disposable VM for the first run.

The Windows entry point has a help-only path that does not start setup:

```powershell
Set-Location windows
.\prepare_new_box.ps1 -Help
```

The destructive `small2zip` utility has a list-only mode:

```powershell
python utils\small2zip.py --list <folder>
```

Concurrent `small2zip` processes now serialize per target with an exclusive
ownership lock; a second process fails closed. See
[Tools and containers](docs/TOOLS_AND_CONTAINERS.md#small2zip) for lock recovery
and metadata limitations.

## Repository documentation

- [Repository guide](docs/REPOSITORY_GUIDE.md) — layout, workflows, ownership,
  and maintenance conventions.
- [Ubuntu and WSL](docs/UBUNTU.md) — the Linux bootstrap flow and the roles of
  the standalone scripts.
- [Tools and containers](docs/TOOLS_AND_CONTAINERS.md) — utility and Docker
  usage boundaries.
- [Security and safety](docs/SECURITY_AND_SAFETY.md) — trust boundaries,
  credentials, destructive operations, and verification expectations.
- [Privacy and secret scan](docs/PRIVACY_AND_SECRETS.md) — credential-scan
  results and remaining personal/organizational identifiers.
- [Reviewed file inventory](docs/FILE_INVENTORY.md) — all 181 pre-existing
  repository files reviewed for this documentation pass.
- [Critical issues](TODO.md) — repository-wide remediation backlog ordered by
  priority.

## Review and validation status

The initial 2026-07-29 review covered all 181 pre-existing files, including
hidden configuration and the former bundled binary. The remediation pass added
static parsing plus isolated tests for cross-process archive locking, Docker
dry-run non-mutation, Git tool arguments, and helper regressions. It did not run
installers, apt changes, real mounts, service/data-root migration, container
builds, or hardware paths. The full Rich-dependent `small2zip` suite remains
unexecuted locally; its new stdlib-only two-process safety regression passed.
