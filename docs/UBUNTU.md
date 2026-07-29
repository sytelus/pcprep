# Ubuntu and WSL

## Status

The `ubuntu/` directory contains an intended bootstrap flow alongside many
standalone and legacy helpers accumulated for different machines. Several
high-impact defects are open in [TODO.md](../TODO.md). Do not treat the directory
as a single safe batch of scripts, and do not run the full bootstrap unattended
until the P0 and bootstrap-integrity issues are resolved.

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

The WSL branch refers to `wsl_prep.sh`, but the repository contains
`wsl_prep.md`. Follow the Markdown instructions manually and treat the stale
prompt as a documentation defect.

## Script families

### Core setup

- `setupbox.sh`, `prepare_new_box.sh`, `min_system.sh`, `extra_install.sh`,
  `cp_dotfiles.sh`, and `gitconfig.sh` form the intended main path.
- `install_miniconda.sh`, `install_dl_frameworks.sh`, `install_rust.sh`,
  `install_fzf.sh`, `brew.sh`, `dotnet.sh`, and `python.sh` install language or
  developer tooling.
- `gitclones.sh`, `create_data_dirs.sh`, `gsettings.sh`, and `codefonts.sh`
  apply personal workspace or desktop preferences.

The current privilege preflight in the package scripts only accepts root or
already-passwordless/cached non-interactive sudo. A normal fresh terminal can
therefore skip required packages while the parent bootstrap continues. This is
tracked as a bootstrap blocker.

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
constraints. The current DL installer hard-codes a PyTorch CUDA channel rather
than deriving a compatible choice from the detected driver; resolve the root
TODO before relying on it.

### Storage, mounts, network, and system administration

`azmount.sh`, `azunmount.sh`, `mount_cifs.sh`, `wsl_vpn.py`, `killer_wifi.sh`,
`cpu_cap.sh`, `update_dsvm.sh`, `vps_setup.sh`, `security_status.sh`,
`unban.sh`, `system.sh`, `sysinfo.sh`, `treesize.sh`, and
`kill_vscode_srv.sh` are standalone operations, not one supported workflow.
Some require root, alter persistent configuration, contain credentials, stop
services, or delete state. `mount_cifs.sh` is currently broken and unsafe for
credentials; do not use it until its P0 item is closed.

### Kubernetes and containers

`kubectl.sh` and the bundled `minikube-linux-amd64` are legacy. The kubectl
repository command is malformed and obsolete, while the 48.6 MB binary has no
documented provenance or checked-in verification record. Prefer a current,
pinned, checksum-verified upstream installation after the TODO is resolved.

The maintained container material lives under `ubuntu/docker/`; see
[Tools and containers](TOOLS_AND_CONTAINERS.md).

## Dotfiles and security-sensitive defaults

`cp_dotfiles.sh` seeds shell, SSH, Codex, Claude, terminal, editor, desktop, and
local-bin content. Some files are copied only when absent, but they still become
the user's active defaults on a new machine.

Review these files before copying anything:

- `.ssh/config` disables host-key verification for every host;
- `.codex/config.toml` grants an agent full filesystem/process access without
  approval prompts;
- `.claude/settings.json` enables all project MCP servers;
- `.bashrc` globally sets `GIT_TEST_ASSUME_ALL_SAFE=1`;
- `.bash_aliases` includes forceful cleanup/revert and approval-bypassing agent
  shortcuts;
- `azmount.yaml` is a credential-bearing configuration template.

These are not safe generic defaults. The root TODO calls for explicit opt-in
profiles and secure baseline settings.

## Archived material

Everything under `archived/ubuntu/` predates the active flow and exists for
reference. It includes old CUDA, ML, home relocation, sandbox, and WSL setup
approaches. Do not use it to fill gaps in the active bootstrap without a fresh
review and a deliberate port.

