# Reviewed file inventory

This ledger records the complete pre-documentation repository snapshot reviewed
on 2026-07-29: **181 files**, excluding `.git/`. Hidden files and the bundled
binary are included. The new `README.md`, root `TODO.md`, and `docs/` files are
outputs of that review and therefore are not part of the 181-file input set.

## Root and editor/container configuration (4)

```text
.codex
.devcontainer/devcontainer.json
.gitignore
.vscode/launch.json
```

`.codex` is an empty marker file. At snapshot time the dev-container definition
selected the GPU image; the remediation pass later made CPU the default and
added an explicit GPU variant. The VS Code launch file targets the two root
smoke scripts; `.gitignore` contains repository exclusions.

## Archived Ubuntu and Windows material (15)

```text
archived/ubuntu/install_all.sh
archived/ubuntu/install_cuda12.1.sh
archived/ubuntu/install_sandbox_old.sh
archived/ubuntu/old_ml.sh
archived/ubuntu/old_move_home.sh
archived/ubuntu/old_wsl_relocate_vhd.bat
archived/ubuntu/old_wsl_setup.sh
archived/windows/codeface.ps1
archived/windows/enable brighness.reg
archived/windows/enable mobility center.reg
archived/windows/install_anaconda.bat
archived/windows/install_gsudo.bat
archived/windows/install_ml.bat
archived/windows/install_python.bat
archived/windows/install_rl.bat
```

These are superseded CUDA/ML/sandbox/home/WSL and Windows install/registry
approaches. They were reviewed as historical inputs and are not supported entry
points.

## macOS (18)

```text
mac/apply_defaults.sh
mac/apply_dotfiles.sh
mac/Brewfile.cask
mac/Brewfile.core
mac/check_python_stack.py
mac/common.sh
mac/dotfiles/pcprep-p10k.zsh
mac/dotfiles/pcprep-shell.bash
mac/dotfiles/pcprep-shell.common.sh
mac/dotfiles/pcprep-shell.zsh
mac/error.txt
mac/prepare_new_box.sh
mac/README.md
mac/requirements-ai.txt
mac/requirements-mlx.txt
mac/revert_defaults.sh
mac/setup_python_ai.sh
mac/verify_setup.sh
```

This set provides the orchestrator, shared functions, Homebrew manifests,
Python/AI setup and checks, macOS defaults/revert, shell/prompt fragments, and
verification. `mac/error.txt` is empty. The existing README is detailed but has
hard-coded local links tracked in the root TODO.

## Root smoke scripts (2)

```text
tests/atari.py
tests/cuda.py
```

These are manual Atari/framework and CUDA smoke examples, not an automated test
suite. Their obsolete APIs/dependency assumptions are tracked in the root TODO.

## Ubuntu/WSL dotfiles and application configuration (19)

```text
ubuntu/.bash_aliases
ubuntu/.bashrc
ubuntu/.claude/settings.json
ubuntu/.codex/.gitignore
ubuntu/.codex/AGENTS_EXISTING_PROJECT.md
ubuntu/.codex/AGENTS_NEW_PROJECT.md
ubuntu/.codex/config.toml
ubuntu/.codex/FULL_CODE_REVIEW.md
ubuntu/.config/gtk-3.0/gtk.css
ubuntu/.config/gtk-3.0/settings.ini
ubuntu/.config/sublime-text-3/Packages/User/Default (Linux).sublime-keymap
ubuntu/.config/sublime-text-3/Packages/User/Package Control.sublime-settings
ubuntu/.config/sublime-text-3/Packages/User/Preferences.sublime-settings
ubuntu/.config/sublime-text-3/Packages/User/Sublimerge.sublime-settings
ubuntu/.config/terminator/config
ubuntu/.inputrc
ubuntu/.local/share/applications/spotify.desktop
ubuntu/.ssh/config
ubuntu/.tmux.conf
```

This group contains interactive shell behavior, aliases, agent configuration and
prompt templates, GTK/Sublime/Terminator/application settings, SSH, readline,
and tmux configuration. Security-sensitive global defaults are called out in
[Security and safety](SECURITY_AND_SAFETY.md).

## Ubuntu/WSL setup, administration, and diagnostics (66)

```text
ubuntu/anaconda.sh
ubuntu/apex.sh
ubuntu/azmount.sh
ubuntu/azmount.yaml
ubuntu/azunmount.sh
ubuntu/brew.sh
ubuntu/codefonts.sh
ubuntu/cp_dotfiles.sh
ubuntu/cpu_cap.sh
ubuntu/create_data_dirs.sh
ubuntu/cuda_diag.sh
ubuntu/cuda_test.py
ubuntu/cudnn_ver.sh
ubuntu/del_submodule.sh
ubuntu/dotnet.sh
ubuntu/extra_install.sh
ubuntu/fix_cuda_repo.sh
ubuntu/git_status.py
ubuntu/gitclones.sh
ubuntu/gitconfig.sh
ubuntu/gsettings.sh
ubuntu/install_azcopy.sh
ubuntu/install_cuda.sh
ubuntu/install_cuda12.4.sh
ubuntu/install_cuda12.6.sh
ubuntu/install_cudnn.sh
ubuntu/install_dl_frameworks.sh
ubuntu/install_docker.sh
ubuntu/install_flash_attn.sh
ubuntu/install_fzf.sh
ubuntu/install_gpg_key.sh
ubuntu/install_miniconda.sh
ubuntu/install_nccl.sh
ubuntu/install_nvidia_drivers.sh
ubuntu/install_rust.sh
ubuntu/install_tailscale.py
ubuntu/install_transformerengine.sh
ubuntu/kill_vscode_srv.sh
ubuntu/killer_wifi.sh
ubuntu/kubectl.sh
ubuntu/measure_flops.py
ubuntu/min_system.sh
ubuntu/minikube-linux-amd64
ubuntu/mount_cifs.sh
ubuntu/nv_container_tk.sh
ubuntu/nvtop.sh
ubuntu/prepare_new_box.sh
ubuntu/python.sh
ubuntu/rl.sh
ubuntu/rundocker.sh
ubuntu/security_status.sh
ubuntu/setupbox.sh
ubuntu/ssh_perms.sh
ubuntu/start_tmux.sh
ubuntu/sysinfo.sh
ubuntu/system.sh
ubuntu/torch_info.py
ubuntu/treesize.sh
ubuntu/unban.sh
ubuntu/uninstall_cuda.sh
ubuntu/uninstall_miniconda.sh
ubuntu/update_dsvm.sh
ubuntu/verify_cuda.sh
ubuntu/vps_setup.sh
ubuntu/wsl_prep.md
ubuntu/wsl_vpn.py
```

These files span the intended bootstrap, language/package installation,
NVIDIA/CUDA/ML setup, dotfile copying, Git/workspace preferences, Azure/CIFS
mounts, Docker/Kubernetes, system/security/network helpers, uninstallation, WSL
instructions, and hardware diagnostics. `minikube-linux-amd64` is the sole
binary: a 48,571,328-byte x86-64 ELF executable. Its missing provenance and
replacement are tracked in the root TODO.

## CPU devbox (14)

```text
ubuntu/docker/cpu-devbox/build_local.sh
ubuntu/docker/cpu-devbox/build_multiarch.sh
ubuntu/docker/cpu-devbox/docker_info.sh
ubuntu/docker/cpu-devbox/docker-move-data.sh
ubuntu/docker/cpu-devbox/Dockerfile
ubuntu/docker/cpu-devbox/dockerprune.sh
ubuntu/docker/cpu-devbox/LEARNINGS.md
ubuntu/docker/cpu-devbox/push_multiarch.sh
ubuntu/docker/cpu-devbox/README.md
ubuntu/docker/cpu-devbox/REQUIREMENTS.md
ubuntu/docker/cpu-devbox/run.sh
ubuntu/docker/cpu-devbox/setup-builder.sh
ubuntu/docker/cpu-devbox/TODO.md
ubuntu/docker/cpu-devbox/verify.sh
```

This is a documented multi-architecture Ubuntu/Miniforge CPU development image
with local/multiarch build, run, verify, inspect, prune, builder, push, and
Docker data-migration operations. Its initial P0 findings were subsequently
remediated; this section remains an inventory of the pre-remediation snapshot.

## GPU devbox (14)

```text
ubuntu/docker/gpu-devbox/build_arm64_native.sh
ubuntu/docker/gpu-devbox/build_local.sh
ubuntu/docker/gpu-devbox/build_multiarch.sh
ubuntu/docker/gpu-devbox/docker_info.sh
ubuntu/docker/gpu-devbox/Dockerfile
ubuntu/docker/gpu-devbox/dockerprune.sh
ubuntu/docker/gpu-devbox/LEARNINGS.md
ubuntu/docker/gpu-devbox/push_multiarch.sh
ubuntu/docker/gpu-devbox/README.md
ubuntu/docker/gpu-devbox/REQUIREMENTS.md
ubuntu/docker/gpu-devbox/run.sh
ubuntu/docker/gpu-devbox/setup-builder.sh
ubuntu/docker/gpu-devbox/TODO.md
ubuntu/docker/gpu-devbox/verify.sh
```

This is the NVIDIA NGC-based counterpart, including an arm64-native path,
local/multiarch builds, runtime verification, inspection, pruning, publishing,
and its own requirements/learnings/backlog.

## Utilities (9)

```text
utils/chmodx.bat
utils/Collect-SleepDiagnostics_v2.ps1
utils/copyallfiles_errors_prompt.txt
utils/copyallfiles.bat
utils/logs_around.ps1
utils/README.md
utils/requirements.txt
utils/small2zip.py
utils/test_small2zip.py
```

This group covers Windows/WSL permission adjustment, sleep and Event Log
diagnostics, Robocopy-based bulk copying, its analysis prompt, and the tested
archive-verify-delete utility. The existing utility README documents behavior
and limitations in depth.

## Windows (20)

```text
windows/aliases.doskey
windows/aliases.reg.bat
windows/codex_firewall.ps1
windows/configure_rust.ps1
windows/copy with title bookmarklet.js
windows/del_chrome_policy.bat
windows/disable_wer.reg
windows/enable_hidden_power.ps1
windows/gitconfig.bat
windows/hide_gallery.bat
windows/install_choco.bat
windows/install_miniconda.ps1
windows/install_pip_packages.ps1
windows/install_rust_prerequisites.ps1
windows/LongPathEnabled.reg
windows/prepare_new_box.ps1
windows/README.md
windows/shutdown_reason.ps1
windows/utilities.ps1
windows/WindowsTerminal/settings.json
```

This set contains the supported PowerShell orchestrator, its comprehensive
README, WinGet and elevated utility work, Rust/Miniconda/Python/Git setup,
DOSKEY aliases, registry/power/Explorer/Chrome/WER helpers, Windows Terminal
settings, firewall policy management, a shutdown-reason helper, and a clipboard
bookmarklet.

## Coverage total

| Group | Files |
| --- | ---: |
| Root/editor/container | 4 |
| Archived | 15 |
| macOS | 18 |
| Root smoke scripts | 2 |
| Ubuntu dotfiles/config | 19 |
| Ubuntu setup/admin/diagnostics | 66 |
| CPU devbox | 14 |
| GPU devbox | 14 |
| Utilities | 9 |
| Windows | 20 |
| **Total** | **181** |

The inventory list above is authoritative; the coverage table is intended as a
quick checksum and should be updated automatically once repository inventory
validation is added to CI.
