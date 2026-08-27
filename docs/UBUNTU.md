# Ubuntu and WSL

## Status

The `ubuntu/` directory contains an intended bootstrap flow alongside many
standalone and legacy helpers accumulated for different machines. The initial
safety blockers were remediated, while supply-chain pinning and native
integration remain in [TODO.md](../TODO.md). Do not treat every standalone
script as part of one supported batch.

The intended bootstrap path now handles Ubuntu 26.04 LTS (Resolute) package and
repository differences on amd64 and arm64. Package availability was checked
against the official Resolute APT indexes; native installation, desktop, WSL,
and GPU integration still need to be exercised on representative machines.

## Intended bootstrap flow

`setupbox.sh` is a download-and-clone convenience wrapper:

```text
setupbox.sh
  -> clone pcprep into ~/GitHubSrc/pcprep
  -> ubuntu/prepare_new_box.sh
       -> optional WSL preparation
       -> cp_dotfiles.sh
       -> min_system.sh
       -> optional WSL utility or CUDA branch
       -> gitconfig.sh
       -> extra_install.sh
       -> install_miniconda.sh
       -> Python/DL packages and AI CLIs when online
```

The orchestrator uses these environment variables:

| Variable | Default | Meaning |
| --- | --- | --- |
| `NO_NET` | auto-detected | `1` selects the limited offline path; `0` permits network-dependent work |
| `user_name` | empty/prompted downstream | Global Git user name |
| `user_email` | empty/prompted downstream | Global Git email |
| `INSTALL_CUDA` | `0` | Opt in to CUDA installation on non-WSL Linux when a compatible GPU is detected |
| `CUDA_VERSION` | `13.2` | Toolkit-only NVIDIA CUDA version aligned with the newest CUDA wheel provided by stable PyTorch |
| `INSTALL_PYTORCH` | `1` | Controls framework installation in the downstream DL script |
| `PYTHON_VERSION` | `3.14` | Latest stable Python feature series installed into Miniconda base; Conda resolves its newest patch release |
| `PYTORCH_VERSION` | `2.13.0` | Reviewed stable PyTorch release |
| `TORCHVISION_VERSION` | `0.28.0` | TorchVision release paired with the reviewed PyTorch version |
| `WSL_DISTRO_NAME` | inherited from WSL | Selects WSL-specific SSH, browser, apt, and Windows credential-manager integration; `/proc/version` is used as a fallback |
| `PCPREP_WIN_GCM_PATH` | auto-detected | Optional WSL path to a nonstandard Windows `git-credential-manager.exe` installation |

The WSL prompt now points to the existing `wsl_prep.md`; follow those manual
host-side instructions before continuing. Ubuntu 26.04 removed `wslu`, and the
upstream PPA has no Resolute suite, so the bootstrap skips that optional package
when unavailable instead of leaving a broken APT source. Standard WSL Windows
interop through `cmd.exe` and `explorer.exe` remains available. Windows SSH
files are located from `%USERPROFILE%` instead of assuming the Windows and Linux
usernames match, and existing WSL SSH files are never overwritten. Git is
installed by `min_system.sh` before Windows Git Credential Manager is configured
using its WSL-safe escaped path. If Windows interop is disabled, the Windows
credential and Tailscale integrations are skipped without breaking the rest of
the bootstrap. Run the orchestrator as the regular WSL user, not with `sudo`.

## Script families

### Core setup

- `setupbox.sh`, `prepare_new_box.sh`, `min_system.sh`, `extra_install.sh`,
  `cp_dotfiles.sh`, and `gitconfig.sh` form the intended main path.
- `install_miniconda.sh`, `install_dl_frameworks.sh`, `install_rust.sh`,
  `install_fzf.sh`, `brew.sh`, `dotnet.sh`, and `python.sh` install language or
  developer tooling.
- `gitclones.sh`, `create_data_dirs.sh`, `gsettings.sh`, and `codefonts.sh`
  apply personal workspace or desktop preferences.

The orchestrator and child package scripts now acquire sudo explicitly and fail
instead of silently skipping required system work. A final required-command
manifest prevents a partial run from reporting “ready.” Microsoft does not yet
publish an Azure CLI `resolute` suite, so Ubuntu 26.04 uses the vendor-documented
`jammy` repository fallback explicitly. Node.js is installed through NVM 0.40.6
using the current LTS release, and the Codex CLI is installed into that
user-owned NVM tree rather than through Ubuntu's older system npm.

### NVIDIA, CUDA, and ML

- Legacy standalone CUDA version installers exist for 12.4 and 12.6. The
  orchestrator uses `install_cuda.sh`, which defaults to toolkit-only CUDA 13.2,
  selects NVIDIA's Ubuntu 22.04/24.04/26.04 repository, supports amd64 and
  arm64/SBSA, and does not install driver packages. NVIDIA does not publish the
  older 13.2 toolkit in its Ubuntu 26.04 repository, so the orchestrator's
  preflight skips that optional toolkit on Resolute instead of using an
  unsupported cross-release repository. PyTorch's `cu132` wheel includes the
  runtime it needs and remains usable with a sufficiently new Windows/WSL or
  native NVIDIA driver.
- `install_nvidia_drivers.sh`, `nv_container_tk.sh`, `install_cudnn.sh`,
  `install_nccl.sh`, `install_flash_attn.sh`, and
  `install_transformerengine.sh` are independent specialist installers.
- `cuda_diag.sh`, `verify_cuda.sh`, `cuda_test.py`, `cudnn_ver.sh`, `nvtop.sh`,
  `measure_flops.py`, and `torch_info.py` inspect or exercise the stack.
- `uninstall_cuda.sh` is destructive and should be used only after reviewing
  its package and filesystem scope.

Framework wheels, drivers, toolkits, and container runtimes have compatibility
constraints. The DL installer maps the driver-reported maximum to the reviewed
PyTorch 2.13.0/TorchVision 0.28.0 `cu126`, `cu130`, `cu132`, or CPU wheel on
amd64 or arm64 and verifies a real tensor operation. Miniconda 26.5.3-1 is
upgraded to the latest Python 3.14 patch available from Anaconda's defaults
channel. TensorFlow is removed because its current stable release has no Python
3.14 wheel; Keras is retained with its PyTorch backend and TensorBoard remains
available. Native GPU validation remains part of deferred integration testing.

### Storage, mounts, network, and system administration

`azmount.sh`, `azunmount.sh`, `mount_cifs.sh`, `wsl_vpn.py`, `killer_wifi.sh`,
`cpu_cap.sh`, `update_dsvm.sh`, `vps_setup.sh`, `security_status.sh`,
`unban.sh`, `system.sh`, `sysinfo.sh`, `treesize.sh`, and
`kill_vscode_srv.sh` are standalone operations, not one supported workflow.
Some require root, alter persistent configuration, stop services, or delete
state. CIFS now reads passwords outside argv and rolls back failed persistent
mount configuration; Azure mounting uses a protected managed-identity config.

### Kubernetes and containers

`kubectl.sh` now configures the signed `pkgs.k8s.io` repository for a selected
minor version. The bundled 48.6 MB executable was removed; `install_minikube.sh`
downloads pinned v1.38.1 for amd64/arm64 and checks the upstream release hash.

The maintained container material lives under `ubuntu/docker/`; see
[Tools and containers](TOOLS_AND_CONTAINERS.md).

## Dotfiles and security-sensitive defaults

`cp_dotfiles.sh` seeds shell, SSH, Codex, Claude, terminal, editor, desktop, and
local-bin content. Some files are copied only when absent, but they still become
the user's active defaults on a new machine.

Review these files before copying anything:

- `.ssh/config` uses normal known-host verification;
- `.codex/config.toml` requires approval, workspace sandboxing, and secret-name
  environment filtering;
- `.claude/settings.json` does not auto-enable project MCP servers;
- `.bashrc` preserves Git ownership checks and reuses one valid SSH agent;
- the explicitly named `claudeyolo` and `codexyolo` helpers bypass normal agent
  safeguards and should be used only intentionally. They invoke only the
  native `$HOME/.local/bin/claude` and `$HOME/.local/bin/codex` executables and
  fail instead of falling through to a Windows executable imported into WSL's
  `PATH`;
- `azmount.yaml` uses managed identity and is installed at mode 0600.

Forceful Git cleanup/revert aliases still exist as interactive user tools; read
their definitions before use.

## Archived material

Everything under `archived/ubuntu/` predates the active flow and exists for
reference. It includes old CUDA, ML, home relocation, sandbox, and WSL setup
approaches. Do not use it to fill gaps in the active bootstrap without a fresh
review and a deliberate port.
