# Ubuntu and WSL

`ubuntu/` has two setup flows, one for a workstation or WSL and one for a VPS, plus many standalone helpers. They support Ubuntu 24.04 and 26.04 on amd64 and arm64. Package names are checked against 26.04's archives, but native desktop and GPU installs still need testing on real machines.

The standalone helpers are not one tested batch. Read a helper before running it, since some change system settings or delete data. Everything under `archived/ubuntu/` is old and kept for reference only.

## Set up a workstation or WSL

From the repository root, as your regular user (not with `sudo`):

```bash
bash ubuntu/prepare_new_box.sh
```

On a new machine, `setupbox.sh` clones this repository into `~/GitHubSrc/pcprep` and then runs the same script.

It asks everything up front: your Git name and email, and on WSL whether you followed [wsl_prep.md](../ubuntu/wsl_prep.md). After the sudo password it runs without questions. To skip the questions too, set `user_name`, `user_email` and `NO_NET` beforehand.

It then runs, in order:

```text
cp_dotfiles.sh      shell, SSH, editor and agent settings
gitconfig.sh        Git identity and defaults
min_system.sh       core packages and build tools
(CUDA or WSL extras, when they apply)
extra_install.sh    everyday command-line tools
                    a check that automatic security updates work
install_miniconda.sh, then Python packages, Node.js, Codex and Claude Code
```

### Switches

| Variable | Default | Effect |
|---|---|---|
| `INSTALL_CUDA` | `0` | `1` installs the NVIDIA CUDA toolkit (never drivers), plus Jupyter, TensorBoard, Transformers, Accelerate, laptop power tools, `nvtop`, and the NFS and CIFS clients |
| `INSTALL_PYTORCH` | `1` | PyTorch, TorchVision, Keras and Lightning. Without an NVIDIA driver you get the CPU build. |
| `INSTALL_AZURE_CLI` | `0` | `1` installs Azure CLI and AzCopy |
| `INSTALL_WORKSTATION_PACKAGES` | `1` | Desktop, media and hardware packages a server doesn't need, such as X11 libraries, `ffmpeg`, `nmap`, FUSE filesystems, sensors and fonts |
| `INSTALL_FUN_PACKAGES` | `0` | Novelties such as `cowsay` and `cmatrix` |
| `NO_NET` | detected | `1` takes the offline path |

These switches affect what gets installed. They don't remove anything an earlier run installed.

**Versions** have reviewed defaults that you can override: `CUDA_VERSION` (13.2 on 24.04, 13.3 on 26.04), `PYTHON_VERSION` (3.14), `PYTORCH_VERSION` and `TORCHVISION_VERSION` (2.13.0 and 0.28.0), `NVM_VERSION` (0.41.0), `MINICONDA_VERSION` (26.5.3-1) and `ZELLIJ_VERSION` (0.46.0). Downloads are checked against a SHA-256, so a different Miniconda or Zellij version also needs `MINICONDA_SHA256`, or `ZELLIJ_SHA256_X86_64` or `ZELLIJ_SHA256_AARCH64`.

**Rarely needed:**
- `PYTORCH_ACCELERATOR` overrides the detected wheel (`cpu`, `cu126`, `cu130` or `cu132`).
- `MINICONDA_FILE` uses a local installer, and `MINICONDA_PYTHON_SERIES` picks the installer's Python series.
- `ALLOW_UNSUPPORTED_AZURE_CLI=1` with `AZURE_CLI_FALLBACK_SUITE` borrows an older Ubuntu's Azure CLI repository.
- `INSTALL_TOOLCHAIN_TEST_PPA=1` adds the Ubuntu Toolchain test-build PPA, and `REMOVE_LEGACY_TOOLCHAIN_TEST_PPA=1` removes one left by an old run.
- `RUSAGE_URL` and `RUSAGE_SHA256` replace the optional `rusage` download.
- `PCPREP_WIN_GCM_PATH` points to a Windows Git Credential Manager in an unusual place.
- `PCPREP_AUDIT_DIR` moves the run logs.

### Good to know

- **Every run is logged** to a private file in `~/.pcprep/`, and `prepare_new_box.latest.log` points to the newest. The log holds the settings, the repository commit, all output and the result. It never records environment variables, so secrets stay out of it.
- **Automatic security updates are checked** on an online machine with systemd: setup confirms that they are on and simulates one, and stops if that fails. To run only the check, which installs nothing: `/usr/bin/python3 -I ubuntu/verify_security_updates.py`
- **Anaconda's Terms of Service** for its default channels are accepted for you, so review [Anaconda's terms](https://www.anaconda.com/legal) first. A working Miniconda from an earlier run is kept.
- **CUDA and PyTorch are separate.** PyTorch brings its own CUDA runtime and picks the wheel that matches your driver. Set `CUDA_VERSION` only when you compile against an exact version. TensorFlow is not installed, because it has no Python 3.14 build yet.
- **On WSL,** sudo stops asking for your password until the next reboot (still per terminal). To undo that, delete `/etc/sudoers.d/99-pcprep-wsl-timestamp-timeout` and run `sudo -k`. Your Windows SSH files and Git Credential Manager are reused, and are skipped if Windows interop is off.

## Set up a VPS

For a VPS that hosts websites through a Cloudflare Tunnel and runs coding agents:

1. **Make sure you log in with an SSH key** (see below).
2. **Run `bash ubuntu/prepare_new_vps.sh`** as your regular user. It is the workstation setup without CUDA, PyTorch, Azure or workstation packages. It first creates `sy_agent`, `sy_dev` and `sy_deploy`, and at the end upgrades every installed package, since the provider's image is often weeks behind. Reboot afterwards if it says so.
3. **Run `sudo bash ubuntu/vps_harden.sh`** from your admin account. Keep that terminal open. From a second terminal, log in with your key and run the confirmation command it prints, within 10 minutes. Otherwise a timer restores the previous settings, even if your first session drops. Do this before you reboot.

### Your SSH key comes first

After hardening, the server accepts only SSH keys, not passwords. It reads the public keys for an account from `~/.ssh/authorized_keys`, or from whatever file `AuthorizedKeysFile` names in `sshd_config`, for example in a `Match User` block. The scripts use whichever file `sshd` uses.

If you can't log in with a key yet, add yours once from your own computer. Make one first with `ssh-keygen -t ed25519` if you need to.

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh shitals@<server> "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
```

On Linux, macOS or Git Bash, `ssh-copy-id shitals@<server>` does the same.

Without a key, `prepare_new_vps.sh` sets up everything else, skips the `sy_*` accounts and tells you how to add them later. `vps_harden.sh` stops before changing anything.

### The `sy_*` accounts

[add_vps_users.sh](../ubuntu/add_vps_users.sh) gives each account passwordless sudo and your public keys. Key lines with options such as `from=` are skipped and reported, because copying them without their limits would be unsafe. Accounts that already exist are left alone.

The accounts start without the toolchain. To give one the toolchain, log in as that account, clone this repository and run `bash ubuntu/prepare_new_box.sh` with the same switches.

### What hardening does

The [script](../ubuntu/vps_harden.sh) also lists these changes at its top.

- **SSH:** keys only. No root login and no X11 or agent forwarding. Port forwarding stays on, for VS Code Remote and `ssh -L`. Each connection gets 3 key attempts and 30 seconds to log in, idle sessions close after 15 minutes, and the log records which key each login used. The port doesn't change.
- **Who keeps SSH access:** your admin account, plus every account with its own `Match User` block in the SSH config. `add_user.sh` writes one for each account it creates, so the `sy_*` accounts keep access. Give any other account such a block, or an `AllowUsers` entry, before you run the script. If an `AllowUsers` list already exists, the script only adds your admin account to it.
- **The provider's account** (such as `ubuntu`) and other cloud-init sudo accounts are disabled after you confirm, but not deleted. The script prints the command that turns each one back on.
- **Firewall:** all incoming traffic is blocked except SSH, and no web ports are opened, since sites arrive through the Tunnel. Keep outbound port 7844 open for the Tunnel, and have apps listen on `127.0.0.1` only. Rules you added yourself stay in place.
- **Fail2ban** bans an address for an hour after 5 failed SSH logins within 10 minutes.
- **Updates:** Ubuntu's security updates install daily, and a required reboot happens at 03:30 server time. The cloudflared, Caddy and GitHub CLI repositories update automatically too, once you've added them.
- **Exposure report:** at the end, any public TCP port other than SSH, and any Docker port published past the firewall, is shown as `CRITICAL` in red. Public UDP ports appear as yellow warnings. Set `NO_COLOR=1` for plain text.
- **Backups:** every file the script changes is copied to `/root/vps_setup_backup_*` first, and a private log goes to `/var/log/`.

If login fails with "Too many authentication failures", your SSH agent is offering too many keys. Name the right key for this server in `~/.ssh/config` with `IdentityFile` and `IdentitiesOnly yes`.

| Option | Effect |
|---|---|
| `SSH_ALLOWED_USER=<admin>` | Names the admin when you run the script from another account. By default the admin is the account that ran `sudo`. |
| `SSH_PORT=2222` | Moves SSH to this port once a fresh login confirms it. Allow the port at your provider first. |
| `AUTO_REBOOT=0` | Never reboots automatically. |
| `AUTO_REBOOT_TIME=04:00` | Reboots at this server time instead of 03:30. |
| `RECIDIVE=1` | Bans repeat offenders from every port for a week. |
| `AGENT_USERS="sy_agent sy_dev"` | Reports these accounts' sudo rights and Docker access. |
| `TUNNEL_HOSTNAME=www.example.com` | Checks the site over HTTPS through Cloudflare. |

Pass an option with `env`, for example `sudo env AUTO_REBOOT=0 bash ubuntu/vps_harden.sh`.

### Check from outside

Run this from a computer outside the VPS's network, with your server's public addresses and the ports that should be closed. Leave out the SSH port.

```bash
python ubuntu/vps_audit.py external www.example.com --origin 192.0.2.10 --origin 2001:db8::10 --port 80 --port 443 --port 3000
```

It tests the site through Cloudflare and checks that the listed ports on the server itself are closed. A site behind a login may answer with a redirect to its sign-in page.

## Dotfiles and shell helpers

`cp_dotfiles.sh` copies shell, SSH, editor, terminal, Codex and Claude settings, and helper commands into `~/.local/bin`. Your own settings files are copied only when they don't exist yet; the helper commands are refreshed on every run, so fixes reach existing machines.

Worth knowing about the defaults:
- Git's editor is `git_editor.sh`: VS Code in a VS Code terminal, on WSL or in a desktop session, and otherwise `$VISUAL`, `$EDITOR`, `micro`, `vim` or `nano`, so commits also work over plain SSH.
- SSH checks host keys as usual. `.bashrc` keeps Git's ownership checks and reuses one SSH agent.
- Codex asks for approval and runs in a sandbox. Claude doesn't turn on a project's MCP servers by itself.
- `claudeyolo` and `codexyolo` skip the agents' safety prompts. Use them on purpose only.
- Some Git aliases force a cleanup or revert. Read them before you use them.

### `ask` and `act`

Two Codex shortcuts in `.bash_aliases`. `ask` answers a question with read-only access, and `act` makes the change you ask for, with full access and no approval prompts. `ask --host` gives `ask` full access as well.

```bash
ask show the top 3 processes by CPU usage
ask what is using disk space in "~/my folder"
act rename "old report.txt" to "new report.txt"
```

Sign in to Codex with ChatGPT first. Quote paths that contain spaces, or type `ask` or `act` alone and enter the request on the next line. In a terminal that was already open, run `source ~/.bash_aliases` first.

## Other scripts

- **Tools:** `install_rust.sh`, `install_fzf.sh`, `brew.sh`, `dotnet.sh`, `python.sh`, `install_dl_frameworks.sh`.
- **Personal preferences:** `gitclones.sh`, `create_data_dirs.sh`, `gsettings.sh`, `codefonts.sh`.
- **NVIDIA:** `install_nvidia_drivers.sh`, `nv_container_tk.sh`, `install_cudnn.sh`, `install_nccl.sh`, `install_flash_attn.sh` and `install_transformerengine.sh` each install one piece on their own. `cuda_diag.sh`, `verify_cuda.sh`, `cuda_test.py`, `cudnn_ver.sh`, `measure_flops.py` and `torch_info.py` check the stack. `uninstall_cuda.sh` removes a lot, so read it first.
- **System and storage:** `add_user.sh`, `azmount.sh`, `azunmount.sh`, `mount_cifs.sh`, `wsl_vpn.py`, `killer_wifi.sh`, `cpu_cap.sh`, `update_dsvm.sh`, `security_status.sh`, `unban.sh`, `system.sh`, `sysinfo.sh`, `treesize.sh`, `kill_vscode_srv.sh`. Some need root, change persistent settings or stop services.
- **Kubernetes:** `kubectl.sh` adds the signed Kubernetes repository, and `install_minikube.sh` installs a pinned, checksum-verified minikube.
- **Containers:** see [Tools and containers](TOOLS_AND_CONTAINERS.md).

Every test suite is listed under [Tests](REPOSITORY_GUIDE.md#tests).
