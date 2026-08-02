# Repository guide

## Purpose and scope

This repository combines four kinds of material:

1. platform bootstrap orchestrators;
2. reusable user configuration and aliases;
3. standalone administration, diagnostic, and recovery helpers; and
4. CPU/GPU development-container definitions.

It is a personal machine configuration repository, not a general-purpose
installer. Names, paths, package choices, Git identity prompts, WSL assumptions,
and security tradeoffs reflect the maintainer's environment. Treat a fork as
source code to review, not as a trusted binary distribution.

## Top-level layout

| Path | Role |
| --- | --- |
| `windows/` | Windows 11 orchestration, WinGet installs, PowerShell helpers, registry settings, aliases, and Windows Terminal configuration |
| `mac/` | macOS bootstrap, Homebrew manifests, Python/AI setup, defaults, shell fragments, and verification |
| `ubuntu/` | Ubuntu/WSL bootstrap, dotfiles, package and accelerator setup, diagnostics, storage/network helpers, and Docker images |
| `utils/` | Cross-cutting copy, archive, Event Log, and sleep-diagnostics tools |
| `tests/` | Manual GPU/framework smoke scripts; not a repository test suite |
| `archived/` | Superseded historical scripts; never an entry point |
| `.devcontainer/` | VS Code dev-container selection and runtime arguments |
| `.vscode/` | Debug launch configuration for the bundled smoke scripts |

The exact pre-documentation snapshot is recorded in
[FILE_INVENTORY.md](FILE_INVENTORY.md).

## Platform workflows

### Windows

`windows/prepare_new_box.ps1` is the supported entry point. It runs user-scoped
WinGet work in the current process and launches a single elevated child phase
for machine-scoped prerequisites and settings. It then configures Rust, aliases,
Git, Miniconda, and Python packages. Use `-Help` for the no-change usage path and
read [windows/README.md](../windows/README.md) for the package list, elevation
model, and current cautions.

The `.bat`, `.reg`, and individual `.ps1` files in `windows/` are implementation
pieces or opt-in maintenance tools. In particular, the Codex firewall script
defaults to audit but has explicit elevated apply/remove modes, and the WER,
Chrome policy, power, and shutdown-reason helpers alter machine state.

### macOS

`mac/prepare_new_box.sh` orchestrates Homebrew, optional GUI applications,
languages and CLIs, Python/AI environments, Git, firewall/defaults, dotfiles,
and a final verification pass. Most optional groups are controlled by
environment variables documented in [mac/README.md](../mac/README.md).

`apply_defaults.sh` has a paired `revert_defaults.sh`, but a revert is not a
complete machine snapshot. `apply_dotfiles.sh` copies shared material from
`ubuntu/`; review that shared source before running the macOS flow.

### Ubuntu and WSL

`ubuntu/setupbox.sh` clones this repository and calls
`ubuntu/prepare_new_box.sh`. The latter is the intended orchestrator, but the
directory also contains many older, standalone, hardware-specific, and
destructive helpers that it does not call. The Linux collection therefore
requires more selection than the Windows or macOS flows. See
[UBUNTU.md](UBUNTU.md) and the root [TODO](../TODO.md).

### Containers

The CPU and GPU devboxes are independent products within the repository. Each
directory contains its own requirements, README, build/run/verify scripts,
learnings, and local TODO. Build scripts expect the repository root as their
Docker build context so they can copy shared dotfiles. The root dev-container
uses the CPU image by default; `.devcontainer/gpu/devcontainer.json` is the
explicit NVIDIA/CUDA variant.

## Configuration ownership

Bootstrap scripts can write or merge files under locations including:

- `~/.bashrc`, `~/.zshrc`, `~/.gitconfig`, `~/.ssh`, `~/.codex`, and
  `~/.claude`;
- `~/.local/bin`, terminal/editor configuration, and macOS preferences;
- Windows registry, environment variables, Windows Terminal settings, services,
  scheduled tasks, firewall rules, and power configuration;
- `/etc/apt`, Docker configuration/data roots, CUDA/NVIDIA packages, mount
  configuration, and system services.

Copy-if-absent behavior is not universal. Review the destination logic in each
script and back up owned configuration before use.

## Maintenance conventions

- Keep one supported orchestrator per platform and label standalone scripts as
  supported, experimental, hardware-specific, or archived.
- Make privileged, destructive, networked, and credential-handling behavior
  visible at the start of each script and in its documentation.
- Add a real `--dry-run` only when it guarantees no persistent state change.
- Pin downloaded artifacts and verify checksums or publisher signatures before
  execution.
- Preserve existing structured configuration when editing it; use backups,
  atomic replacement, rollback, and post-change verification.
- Add repeatable tests for idempotence, interruption, partial failure, hostile
  input, and concurrent execution before calling a workflow unattended-safe.
- Move superseded tools into `archived/` rather than leaving multiple plausible
  entry points in the active platform directory.

## Validation model

This work used static parsing/source inspection on Windows plus isolated tests
for the `small2zip` cross-process lock, Docker dry-run, Git tool commands, and
helper regressions. It did not install packages or exercise macOS, Ubuntu, WSL,
CUDA, real Docker/systemd migration, Homebrew, apt, WinGet, mounts, or hardware
paths. The full Rich-dependent `small2zip` suite was not available, but its new
stdlib-only two-process safety test passed. Native CI and disposable integration
tests remain necessary; parsing is not evidence that a bootstrap completed.
