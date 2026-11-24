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
- Test behavior, not source text. A test runs the real script or function
  against temporary files and fakes, and checks what it installs, deletes or
  writes. Don't add tests that grep a script for a string or version number.
- Keep each suite fast: start one shell or process per scenario and check
  several cases in it, rather than one process per assertion.

## Tests

Every suite is offline. None needs root, a network connection or real
installers, and each finishes in seconds. Run the Linux suites on Ubuntu or in
WSL, from the repository root.

| Suite | What it protects | Run | Time |
| --- | --- | --- | --- |
| `ubuntu/test_helpers.sh` | Package selection switches, dotfile and Codex-update migration, CUDA release defaults, startup prompts, Miniconda reruns, the run audit log, deletion and mount guards, agent shortcuts | `bash ubuntu/test_helpers.sh` | ~3 s |
| `ubuntu/test_gitconfig.sh` | Git identity validation, removal of the old URL rewrite, the editor fallback, merge and diff commands | `bash ubuntu/test_gitconfig.sh` | <1 s |
| `ubuntu/test_codex_shortcuts.py` | The `ask`/`act` shortcuts: request quoting, sandbox choice, credential removal, help | `python3 ubuntu/test_codex_shortcuts.py` | ~3 s |
| `ubuntu/test_vps_access.py` | VPS SSH staging, confirmation and rollback, firewall migration, the SSH allowlist, the provider account, the exposure report | `cd ubuntu && python3 -m unittest test_vps_access` | <1 s |
| `ubuntu/test_verify_security_updates.py` | The automatic security-update check | `cd ubuntu && python3 -m unittest test_verify_security_updates` | <1 s |
| `ubuntu/docker/cpu-devbox/test_docker_move_data.sh` | Docker data-root migration: dry run changes nothing, paths stay contained | `bash ubuntu/docker/cpu-devbox/test_docker_move_data.sh` | <1 s |
| `utils/test_small2zip.py` | `small2zip` never deletes a source that isn't safely archived: verification, cancellation, cross-process locks, appends, metadata, CLI guards. Needs `utils/requirements.txt` | `cd utils && python test_small2zip.py` | 1–3 s |
| `windows/test_codex_shortcuts.ps1` | The PowerShell `ask`/`act` shortcuts | `powershell -NoProfile -File windows\test_codex_shortcuts.ps1` | ~2 s |
| `windows/test_git_status.ps1` | `gstatall` status for each repository state, using local repositories only | `powershell -NoProfile -File windows\test_git_status.ps1` | ~5 s |

`tests/atari.py` and `tests/cuda.py` are manual smoke scripts for ML stacks and
GPUs, not part of these suites.

## Validation model

The suites above check script logic with fakes. They do not install packages or
exercise macOS, real Ubuntu or WSL bootstraps, CUDA, Docker or systemd
migrations, Homebrew, apt, WinGet, mounts, SSH changes on a real server, or
hardware. Native CI and disposable integration machines remain necessary;
passing tests are not evidence that a bootstrap completed.
