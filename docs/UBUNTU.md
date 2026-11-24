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
       -> gitconfig.sh
       -> min_system.sh
       -> optional WSL utility or CUDA branch
       -> extra_install.sh
       -> verify automatic security updates when online with systemd
       -> install_miniconda.sh
       -> Python/DL packages and AI CLIs when online
```

The orchestrator uses these environment variables:

| Variable | Default | Meaning |
| --- | --- | --- |
| `NO_NET` | auto-detected | `1` selects the limited offline path; `0` permits network-dependent work |
| `user_name` | existing Git value or startup prompt | Global Git user name; set it to bypass the prompt |
| `user_email` | existing Git value or startup prompt | Global Git email; set it to bypass the prompt |
| `INSTALL_CUDA` | `0` | Set to `1` to request the NVIDIA toolkit on supported native hardware and include the optional ML, laptop power-management, and network-filesystem tools listed below |
| `INSTALL_AZURE_CLI` | `0` | Set to `1` to request Azure CLI and AzCopy together |
| `INSTALL_WORKSTATION_PACKAGES` | `1` (`0` in `prepare_new_vps.sh`) | Desktop, media and hardware packages a server does not need: clipboard and X11/OpenGL/OpenCV/MPI libraries, Mercurial and Subversion, `ffmpeg`, `ghostscript`, `pdftk-java`, `nmap`, removable-media and FUSE filesystems, sensors, disk-health and power tools, terminal fonts, and the multiverse repository |
| `CUDA_VERSION` | `13.2` on 24.04; `13.3` on 26.04 | Toolkit-only NVIDIA CUDA version selected from the native repository; override it when compiling against an exact version |
| `INSTALL_PYTORCH` | `1` | Install PyTorch, TorchVision, Keras, and Lightning. A machine without an NVIDIA driver gets CPU PyTorch. Set to `0` to skip these packages |
| `PYTORCH_ACCELERATOR` | `auto` | Override driver detection with `cpu`, `cu126`, `cu130`, or `cu132` |
| `NVM_VERSION` | `0.41.0` | NVM release used to install and activate the current Node.js LTS |
| `PYTHON_VERSION` | `3.14` | Latest stable Python feature series installed into Miniconda base; Conda resolves its newest patch release |
| `MINICONDA_VERSION` | `26.5.3-1` | Miniconda installer release for a new Python environment |
| `MINICONDA_PYTHON_SERIES` | `py313` | Python series embedded in the Miniconda installer. The online setup then installs the requested `PYTHON_VERSION` |
| `MINICONDA_FILE` | download when online | Use a local Miniconda installer file |
| `MINICONDA_SHA256` | digest of the default installer | Required SHA-256 of a downloaded installer when `MINICONDA_VERSION` or `MINICONDA_PYTHON_SERIES` changes; a mismatched download is deleted before it runs |
| `ZELLIJ_VERSION` | `0.46.0` | Zellij release; set `ZELLIJ_SHA256_X86_64` or `ZELLIJ_SHA256_AARCH64` (the published binary digest) with another version |
| `PYTORCH_VERSION` | `2.13.0` | Reviewed stable PyTorch release |
| `TORCHVISION_VERSION` | `0.28.0` | TorchVision release paired with the reviewed PyTorch version |
| `WSL_DISTRO_NAME` | inherited from WSL | Selects WSL-specific SSH, browser, apt, and Windows credential-manager integration; `/proc/version` is used as a fallback |
| `PCPREP_WIN_GCM_PATH` | auto-detected | Optional WSL path to a nonstandard Windows `git-credential-manager.exe` installation |
| `PCPREP_AUDIT_DIR` | `~/.pcprep` | Private directory containing one complete audit log for every orchestrator run |
| `ALLOW_UNSUPPORTED_AZURE_CLI` | `0` | With `INSTALL_AZURE_CLI=1`, permit an unsupported cross-release repository if the running release has no native Azure CLI package |
| `AZURE_CLI_FALLBACK_SUITE` | `noble` | `noble` or `jammy` suite used only when the unsupported Azure CLI fallback is enabled |
| `INSTALL_TOOLCHAIN_TEST_PPA` | `0` | Opt in to the Ubuntu Toolchain test-build PPA instead of staying on supported archive packages |
| `INSTALL_FUN_PACKAGES` | `0` | Install optional desktop and novelty programs such as `cowsay` and `cmatrix` |
| `REMOVE_LEGACY_TOOLCHAIN_TEST_PPA` | `0` | Remove the test-build PPA left by an older pcprep run; ignored when installation of that PPA is enabled |
| `RUSAGE_URL` | reviewed Cosmopolitan binary | Override the optional portable `rusage` download location together with `RUSAGE_SHA256` |
| `RUSAGE_SHA256` | reviewed digest | Required SHA-256 for the `rusage` asset; a changed upstream binary is not installed silently |

For a VPS used for web hosting and agent development, run this from the repository
root as your regular user.

```bash
bash ubuntu/prepare_new_vps.sh
```

**Your SSH key comes first.** After hardening, the server accepts SSH logins
only with a key, not a password. The server lists the public keys allowed for
an account in that account's `~/.ssh/authorized_keys`. If yours isn't there
yet, add it once from your own computer (create a key first with
`ssh-keygen -t ed25519` if you don't have one):

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh shitals@<server> "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
```

On Linux, macOS or Git Bash, `ssh-copy-id shitals@<server>` does the same.
Without a key, `prepare_new_vps.sh` still sets up everything else but skips the
`sy_*` accounts and says how to add them later, and `vps_harden.sh` stops before
changing anything.

The wrapper first runs [add_vps_users.sh](../ubuntu/add_vps_users.sh), which
creates `sy_agent`, `sy_dev` and `sy_deploy` with passwordless sudo and the same
SSH public keys as your account (the plain key lines of your
`~/.ssh/authorized_keys`; lines with options such as `from=` are skipped and
reported). Existing accounts are left unchanged. The new accounts get no
toolchain of their own; to install it, log in as the account, clone this
repository, and run `bash ubuntu/prepare_new_box.sh` with the same switches.

The wrapper sets `INSTALL_CUDA=0`, `INSTALL_PYTORCH=0`, `INSTALL_AZURE_CLI=0`, and
`INSTALL_WORKSTATION_PACKAGES=0`.
This keeps Git, compilers, Node.js, Python, Codex, and Claude Code. With
`INSTALL_CUDA=0`, setup skips Jupyter, TensorBoard, Transformers, Accelerate,
TLP (including `tlp-rdw`), NVIDIA PRIME, `nvtop`, `nvitop`, the NFS and CIFS
clients, and the CIFS mount helper. These switches control new installations.
Packages and running services from earlier setups require separate review.

Before installing packages, the orchestrator completes one startup questionnaire:
the WSL manual-step confirmation when applicable, Git identity, and the offline
fallback confirmation if connectivity detection fails. Existing global Git
identity values are offered as defaults. After the immediately following sudo
authorization succeeds, the repository-owned setup steps no longer prompt for
configuration input. Set `user_name`, `user_email`, and `NO_NET` ahead of time
to automate those answers as well.

The online Miniconda setup automatically accepts Anaconda's Terms of Service
for the `pkgs/main` and `pkgs/r` default channels for the current user before
its first unattended package transaction. It reapplies the acceptance after
upgrading the base environment in case the ToS plugin was replaced. Each
acceptance is visible in the per-run audit log. Review
[Anaconda's legal terms](https://www.anaconda.com/legal) before running the
online bootstrap. On a rerun, a working existing Miniconda installation is
preserved instead of applying the older bootstrap installer over its updated
base environment; the Python version transaction and ToS checks remain
idempotent.

## Per-run audit trail

Every non-root invocation of `ubuntu/prepare_new_box.sh` creates a uniquely
named log such as `~/.pcprep/prepare_new_box.20260827T220000Z.A1b2C3.log` and
updates `~/.pcprep/prepare_new_box.latest.log` to point to the newest run. The
directory is mode `0700`, and each log is mode `0600`.

The log begins before prompts, network checks, or privileged work. It records
the start time, script hash, repository commit and clean/dirty state, invoking
user, host and kernel, WSL detection, and the reviewed installer configuration.
All subsequent stdout and stderr from the orchestrator and its child installers
is mirrored into the log. A final record contains the result, exit status,
duration, and finish time. Signal exits are identified; if the process is
forcibly killed and cannot run its exit trap, the missing final record leaves
the run visibly incomplete.

The audit deliberately does not enable shell tracing or dump the process
environment, which avoids intentionally recording passwords, tokens, and
unrelated secrets. Installer output can still contain system paths or other
machine details, which is why the audit directory and logs are private. Set
`PCPREP_AUDIT_DIR` before launch only when the logs need to live somewhere other
than `~/.pcprep`.

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
manifest checks for missing tools. Git removes the exact global rule from
older pcprep runs that redirected all GitHub HTTPS URLs to SSH. Each clone URL
then uses the protocol you chose unless you configured another rewrite yourself.

When Azure tools are enabled, setup checks Microsoft's repository for the
running Ubuntu release and CPU architecture. If the native package is missing,
it reports that Azure CLI was skipped and still attempts AzCopy. Node.js uses
the current LTS through NVM. Codex setup and the Linux `codexupdate` command
use OpenAI's standalone installer and verify `~/.local/bin/codex --version`.

On an online Ubuntu host running systemd, setup checks that APT's automatic
refresh and upgrade settings are enabled and both timers are enabled and active.
It checks the services those timers start for masking or a recorded failure,
refreshes the package lists, checks that the running release's Ubuntu
security repository is eligible, and simulates an unattended upgrade. A failed
check stops setup. Offline and non-systemd runs report that verification was
skipped. To run just the check, use this command from the repository root.

```bash
/usr/bin/python3 -I ubuntu/verify_security_updates.py
```

The check displays the packages the updater would install. It does not install
the updates or reboot the server.

The Ubuntu Toolchain test-build PPA is disabled by default on both releases.
Set `INSTALL_TOOLCHAIN_TEST_PPA=1` only when test compiler packages are
intentional. An older run may already have added the PPA; set
`REMOVE_LEGACY_TOOLCHAIN_TEST_PPA=1` once to remove that source during a rerun.
The optional portable `rusage` command is downloaded for amd64 or arm64 from
Cosmopolitan's current binary directory and must match the reviewed SHA-256
before installation.

On WSL, immediately after startup sudo authorization, the orchestrator
installs `/etc/sudoers.d/99-pcprep-wsl-timestamp-timeout` with mode `0440`. The
drop-in applies `Defaults timestamp_timeout=153722867280912930` system-wide.
Ubuntu 26.04's `sudo-rs` does not support the traditional negative “never
expire” value; this is its largest runtime-safe whole-minute timeout and is
effectively non-expiring. Sudo timestamp records remain scoped normally (usually
per terminal) and are invalidated across reboot. The candidate drop-in and the
aggregate sudoers policy are checked with `visudo` during installation. To
restore the distro default, remove that drop-in with sudo and run `sudo -k` to
invalidate existing timestamp records.

Privilege preflight first tries a harmless noninteractive `sudo` command. This
allows passwordless or still-cached authorization to remain unattended on
Ubuntu 26.04, where sudo-rs otherwise asks for authentication for `sudo -v`
even under a `NOPASSWD` policy. When no authorization is available, the startup
questionnaire is followed by the normal password prompt before setup begins.

### NVIDIA, CUDA, and ML

- Legacy standalone CUDA version installers exist for 12.4 and 12.6. The
  orchestrator uses `install_cuda.sh`, selects NVIDIA's native Ubuntu
  22.04/24.04/26.04 repository, supports amd64 and arm64/SBSA, and does not
  install driver packages. The native toolkit default is CUDA 13.2 on Ubuntu
  22.04/24.04 and CUDA 13.3 on Ubuntu 26.04 because NVIDIA's Resolute repository
  does not carry 13.2. PyTorch independently installs its reviewed `cu132`
  wheel, which carries its own runtime. Set `CUDA_VERSION=13.2` explicitly when
  an extension build requires an exact match; the preflight will then report
  that the package is unavailable on Resolute instead of mixing repositories.
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
3.14 wheel. Keras uses its PyTorch backend when PyTorch is selected. TensorBoard
is installed only with `INSTALL_CUDA=1`. Native GPU validation remains part of
deferred integration testing.

### Storage, mounts, network, and system administration

The [VPS hardening script](../ubuntu/vps_harden.sh) lists its system changes at the top.

For a VPS serving sites through Cloudflare Tunnel, run the following from the
checkout, logged in as your admin account with your SSH key.

```bash
sudo bash ubuntu/vps_harden.sh
```

The account that runs `sudo` is the admin. To run it from another account, name
the admin: `sudo env SSH_ALLOWED_USER=shitals bash ubuntu/vps_harden.sh`. The
script stops before changing anything if the admin has no SSH key on the server.

SSH uses the existing port (usually 22). The script opens no public web ports.
Bind each origin to loopback or a private container network. Keep outbound TCP
and UDP 7844 available for the tunnel. Review any existing web allow rules on
the host and at the provider, including rules left by older installs.

When access settings change, keep the first terminal open. From a second
terminal, connect with your SSH key and run the printed `sudo` confirmation
command within ten minutes. A timer restores the previous settings on timeout
even if the first session disconnects. Finish this step before rebooting.
For a port move, allow the new port at the provider first. Setup copies simple
UFW source restrictions and asks for a manual migration on complex policies.
Review any operator-owned old-port rules after a successful move.

**SSH settings.** Login is key-only, with no root login and no X11 or agent
forwarding. Port forwarding stays on, for VS Code Remote and `ssh -L`. Each
connection gets 3 key attempts and 30 seconds to log in; a session whose client
stops answering for 15 minutes is closed; and the log records the fingerprint
of the key each login used. If your SSH agent holds several keys and login
fails with "Too many authentication failures", name the key for this server in
`~/.ssh/config` with `IdentityFile` and `IdentitiesOnly yes`. OpenSSH already
uses modern ciphers, and on Ubuntu 26.04 it also slows down repeated failures
from one address; fail2ban adds bans on both releases.

**Who keeps SSH access.** If no `AllowUsers` list exists yet, the script
creates one with the admin plus every existing non-root account that has its
own `Match User <name>` block in `sshd_config` or `sshd_config.d/*.conf`.
`add_user.sh` writes such a block for each account it creates, so `sy_agent`,
`sy_dev` and `sy_deploy` keep access. The script prints the accounts it adds.
An account created another way loses SSH access unless you give it a
`Match User` block or an `AllowUsers` entry first. An existing `AllowUsers`
list is left as it is, apart from adding the admin.

**Provider account.** After the new login is confirmed (or on a rerun with
nothing to change), the cloud image's default account, such as `ubuntu`, and any
other account in cloud-init's `/etc/sudoers.d/90-cloud-init-users` are disabled,
not deleted: the password is locked, the account expires (which also blocks SSH
keys) and the shell becomes `nologin`. The admin, the invoking `sudo` user and
the accounts kept in the SSH allowlist are never disabled. The script prints the
command that re-enables each account.

**Updates.** Ubuntu's own security updates install daily, and a required reboot
happens at 03:30 server time. Packages from the cloudflared, Caddy and GitHub
CLI repositories update automatically too, once those repositories are set up.
Other third-party repositories are not updated automatically.

**Exposure report.** The report marks public TCP listeners other than SSH, and
Docker ports published past the firewall, as `CRITICAL` in bold red, and other
public UDP listeners as yellow warnings. It does not stop the script. Set
`NO_COLOR=1` for plain text.

| Optional setting | Effect |
|---|---|
| `SSH_PORT=2222` | Move SSH to this port after confirming a fresh login. |
| `AUTO_REBOOT=0` | Never reboot automatically. By default required reboots happen at `AUTO_REBOOT_TIME`. |
| `AUTO_REBOOT_TIME=04:00` | Reboot time in the server's own timezone (default 03:30). |
| `RECIDIVE=1` | Enable week-long, all-port bans for repeat offenders. |
| `AGENT_USERS="sy_agent sy_dev"` | Report passwordless sudo rules and Docker group membership for these accounts. |
| `TUNNEL_HOSTNAME=www.example.com` | Check HTTPS through Cloudflare after the site is deployed. |

Test direct exposure from a computer outside the VPS network. Supply your own
public IPv4 and IPv6 addresses and the TCP ports intended to be private. Omit
the port intentionally used for public SSH. With SSH on 22, for example:

```bash
python ubuntu/vps_audit.py external www.example.com --origin 192.0.2.10 --origin 2001:db8::10 --port 80 --port 443 --port 3000
```

This checks one external vantage point. A Cloudflare HTTPS response confirms
the public route, while the direct checks independently test the listed origin
ports. An authenticated site may redirect to its sign-in page.

`azmount.sh`, `azunmount.sh`, `mount_cifs.sh`, `wsl_vpn.py`, `killer_wifi.sh`,
`cpu_cap.sh`, `update_dsvm.sh`, `vps_harden.sh`, `security_status.sh`,
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
local-bin content. User-owned configuration files are copied only when absent,
but they still become the user's active defaults on a new machine. The explicit
helper-command list under `~/.local/bin` is pcprep-managed and is refreshed on
every run so compatibility and security fixes propagate to existing machines.
A rerun also removes two obsolete `set ...` Readline lines from older pcprep
`.bashrc` versions and updates the original npm-based `codexupdate` function in
an existing Ubuntu `.bash_aliases`. Customized function bodies are preserved.

Review these files before copying anything:

- `gitconfig.sh` makes `~/.local/bin/git_editor.sh` Git's editor: VS Code in a
  VS Code terminal, WSL or a desktop session, otherwise `$VISUAL`, `$EDITOR`,
  `micro`, `vim` or `nano`, so commits work over plain SSH;
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

## Codex `ask` and `act`

`ubuntu/.bash_aliases` includes the supplied Codex shortcuts v3. `ask` sends a
one-shot English inspection request with a read-only filesystem sandbox; `act`
performs requested changes with full access and no per-command approvals.
`ask --host` explicitly selects full access for inspection. Both use the native
`$HOME/.local/bin/codex`, like `codexyolo`, and fail if it is missing.

```bash
source ~/.bash_aliases
ask show the top 3 processes by CPU usage
ask what is using disk space in "~/my folder"
act rename "old report.txt" to "new report.txt"
ask --help
act --help
```

Help is local and needs no Codex installation or login. For requests, sign in to
Codex with ChatGPT. API-key overrides are unset only in the invocation's subshell.
Quote paths with spaces, or enter `ask`/`act` alone to read one raw request line.
Normal shell parsing still applies to inline text. In WSL, the environment is
the WSL distribution. Existing terminals must source the updated alias file;
the dotfile installer's no-clobber behavior preserves an existing copy.

Run `python3 ubuntu/test_codex_shortcuts.py` from the repository root for offline
tests using a fake native Codex executable; no model requests are made. Every
Ubuntu test suite is listed under
[Tests](REPOSITORY_GUIDE.md#tests).

## Archived material

Everything under `archived/ubuntu/` predates the active flow and exists for
reference. It includes old CUDA, ML, home relocation, sandbox, and WSL setup
approaches. Do not use it to fill gaps in the active bootstrap without a fresh
review and a deliberate port.
