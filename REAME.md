# pcprep

`pcprep` is a personal, opinionated collection of workstation bootstrap scripts,
development-container definitions, diagnostics, and maintenance utilities for
Windows, macOS, Ubuntu, and WSL.

> [!CAUTION]
> These scripts change package installations, user configuration, operating-system
> settings, and—in a few cases—stored data. This repository is not presently safe
> to run unattended end to end. Read [TODO.md](TODO.md) and
> [Security and safety](docs/SECURITY_AND_SAFETY.md) before running a script.

## Supported entry points

| Environment | Main entry point | Platform documentation | Current state |
| --- | --- | --- | --- |
| Windows 11 | `windows/prepare_new_box.ps1` | [Windows setup](windows/README.md) | Coherent orchestrated setup; review its confirmation and security notes first |
| macOS | `mac/prepare_new_box.sh` | [macOS setup](mac/README.md) | Coherent orchestrated setup with many opt-out environment variables |
| Ubuntu / WSL | `ubuntu/prepare_new_box.sh` | [Ubuntu and WSL](docs/UBUNTU.md) | Mixed-generation collection; known blockers must be fixed before unattended use |
| CPU containers | `ubuntu/docker/cpu-devbox/` | [CPU devbox](ubuntu/docker/cpu-devbox/README.md) | Build and run scripts for an Ubuntu/Miniforge image |
| NVIDIA GPU containers | `ubuntu/docker/gpu-devbox/` | [GPU devbox](ubuntu/docker/gpu-devbox/README.md) | NGC-based image; requires an NVIDIA-capable runtime |

Run platform setup from its own directory. Do not run scripts from
`archived/`; they are retained only as historical references.

## Start here

1. Read the platform-specific README above.
2. Review the [priority-ordered issues](TODO.md), especially every P0 item.
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

Do not run two `small2zip` processes against the same target. See
[Tools and containers](docs/TOOLS_AND_CONTAINERS.md#small2zip) for its data-loss
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
- [Reviewed file inventory](docs/FILE_INVENTORY.md) — all 181 pre-existing
  repository files reviewed for this documentation pass.
- [Critical issues](TODO.md) — repository-wide remediation backlog ordered by
  priority.

## Review and validation status

The 2026-07-29 documentation review covered every pre-existing file, including
hidden configuration files and the bundled binary. Validation was deliberately
non-invasive: PowerShell and Bash parsing, JSON/TOML parsing, Python syntax
parsing, JavaScript parsing, link checks, and repository inspection. No setup,
installer, package-manager, operating-system configuration, container build, or
destructive utility was executed. Static validation proves syntax and entry-path
behavior only; it does not prove a successful installation on each platform.
The `small2zip` unit suite was not run because the available Python environments
did not contain its `rich` dependency; no dependency was installed during this
read-only validation.
