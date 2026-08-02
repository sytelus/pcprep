# Ubuntu and WSL

## Status

The `ubuntu/` directory contains an intended bootstrap flow alongside many
standalone and legacy helpers accumulated for different machines. The initial
safety blockers were remediated, while supply-chain pinning and native
integration remain in [TODO.md](../TODO.md). Do not treat every standalone
script as part of one supported batch.

## Intended bootstrap flow

`setupbox.sh` is a download-and-clone convenience wrapper:

```text
setupbox.sh
  -> clone pcprep into ~/GitHubSrc/pcprep
  -> ubuntu/prepare_new_box.sh
       -> optional WSL or CUDA branch
       -> cp_dotfiles.sh
       -> min_system.sh
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
| `INSTALL_PYTORCH` | `1` | Controls framework installation in the downstream DL script |
| `WSL_DISTRO_NAME` | inherited from WSL | Selects WSL-specific SSH, browser, apt, and Windows credential-manager integration |

The WSL prompt now points to the existing `wsl_prep.md`; follow those manual
host-side instructions before continuing.

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
manifest prevents a partial run from reporting “ready.”

### NVIDIA, CUDA, and ML

- CUDA version installers exist for 12.4, 12.6, and 12.8. Only 12.8 is selected
  by the current orchestrator when `INSTALL_CUDA=1`.
- `install_nvidia_drivers.sh`, `nv_container_tk.sh`, `install_cudnn.sh`,
  `install_nccl.sh`, `install_flash_attn.sh`, and
  `install_transformerengine.sh` are independent specialist installers.
- `cuda_diag.sh`, `verify_cuda.sh`, `cuda_test.py`, `cudnn_ver.sh`, `nvtop.sh`,
  `measure_flops.py`, and `torch_info.py` inspect or exercise the stack.
- `uninstall_cuda.sh` is destructive and should be used only after reviewing
  its package and filesystem scope.

Framework wheels, drivers, toolkits, and container runtimes have compatibility
constraints. The DL installer maps the driver-reported maximum to the reviewed
PyTorch 2.12.1 `cu126`, `cu130`, `cu132`, or CPU wheel and verifies a real tensor
operation. Native GPU validation remains part of deferred integration testing.

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
- approval-bypassing agent aliases were removed;
- `azmount.yaml` uses managed identity and is installed at mode 0600.

Forceful Git cleanup/revert aliases still exist as interactive user tools; read
their definitions before use.

## Archived material

Everything under `archived/ubuntu/` predates the active flow and exists for
reference. It includes old CUDA, ML, home relocation, sandbox, and WSL setup
approaches. Do not use it to fill gaps in the active bootstrap without a fresh
review and a deliberate port.
