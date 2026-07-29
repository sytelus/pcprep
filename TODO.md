# Critical issues and remediation backlog

This is the repository-wide, priority-ordered backlog produced by the
2026-07-29 full-file review. The per-image TODO files under `ubuntu/docker/`
remain useful for image-specific improvements; this file lists defects and
risks that can cause data loss, security compromise, a broken system, or a
misleadingly successful bootstrap.

Priority meanings:

- **P0 — stop use:** a credible data-loss, credential, host-integrity, or
  identity-verification failure in the current path.
- **P1 — fix before unattended use:** a central workflow can fail silently,
  install an incompatible/untrusted result, or cannot be reproduced or tested.
- **P2 — important correctness:** a narrower or standalone path is broken,
  misleading, or operationally unsafe.

## P0 — stop use

### 1. Add cross-process locking and ownership to `small2zip`

**Evidence:** `utils/README.md` documents that a second process can delete the
first process's `<folder>.zip.partial`; whichever process publishes last can
replace the other archive, and both may then delete source data.

**Impact:** concurrent runs against the same output can corrupt or replace the
archive and irreversibly delete files.

**Done when:** a per-source/output lock has unambiguous ownership, stale-lock
recovery is conservative, publication verifies the lock is still owned, and a
two-process regression test proves that the losing process cannot alter the
partial/final archive or delete source files.

### 2. Make Docker data-root migration transactional and make `--dry-run` true

**Evidence:** `ubuntu/docker/cpu-devbox/docker-move-data.sh` documents
`--dry-run` as “no changes,” but the flag applies only to `rsync`; the script can
still create/chmod destinations, stop/restart Docker, edit configuration, and
move directories. Service-stop errors and an empty `docker info` result do not
reliably stop migration, and the no-`jq` branch overwrites existing
`daemon.json` settings.

**Impact:** a trial run can change the host, a live Docker store can be copied,
configuration can be discarded, and an inconclusive migration can delete or
hide the old store.

**Done when:** dry-run performs no persistent mutation; source/destination are
resolved and containment-checked; service stops, copy, config merge, restart,
and root-dir verification all fail closed; the old store remains recoverable
until a conclusive count/byte/content verification; rootless and bind-mount
paths have native, tested persistence; and failure-injection tests cover every
phase.

### 3. Stop moving an entire apt sources file to remove one CUDA entry

**Evidence:** `ubuntu/fix_cuda_repo.sh` scans both
`/etc/apt/sources.list` and `/etc/apt/sources.list.d`, then moves any whole file
containing a matching CUDA line into a disabled directory.

**Impact:** if the main sources file also contains Ubuntu repositories, a CUDA
cleanup can remove the machine's normal package sources and break apt updates.

**Done when:** the script backs up files, edits only matching CUDA entries,
never relocates `/etc/apt/sources.list` wholesale, preserves formatting and
unrelated repositories, validates the result with apt, and automatically rolls
back on failure.

### 4. Restore SSH server identity verification in the default dotfiles

**Evidence:** `ubuntu/.ssh/config` applies `StrictHostKeyChecking no` and
`UserKnownHostsFile /dev/null` to `Host *`; `ubuntu/cp_dotfiles.sh` can copy this
configuration onto a new machine.

**Impact:** all SSH connections accept unverified host keys, enabling silent
man-in-the-middle impersonation and credential/session theft.

**Done when:** the default uses normal strict known-host behavior, exceptions
are narrow and explicit, known hosts are provisioned through a trusted channel,
and tests confirm the bootstrap never weakens global SSH verification.

### 5. Replace the broken CIFS credential and fstab writer

**Evidence:** `ubuntu/mount_cifs.sh` accepts a plaintext password as `$4`, then
uses single-quoted `sudo bash -c` snippets whose `$1`/`$3`/`$4` are evaluated in
a new root shell without those positional parameters. It appends duplicate
fstab entries and requests world-writable `0777` file/directory modes.

**Impact:** secrets leak through command history/process arguments, blank or
misnamed credential/fstab data is written, mounts fail or become corruptly
persistent, and every local user can modify mounted files.

**Done when:** secrets are read without echo or command-line exposure, written
atomically with root-only permissions, inputs are validated/escaped, fstab is
updated idempotently with backup/rollback, least-privilege modes are the
default, and tests cover spaces, metacharacters, reruns, and mount failure.

### 6. Make high-risk agent and Git settings explicit opt-ins

**Evidence:** the copied defaults combine Codex `approval_policy = "never"` and
`sandbox_mode = "danger-full-access"`, automatic enablement of all project MCP
servers for Claude, approval-bypassing aliases, and global
`GIT_TEST_ASSUME_ALL_SAFE=1` in `.bashrc`.

**Impact:** a malicious repository, tool server, prompt, or mistaken command can
act across the host without an approval boundary, while Git's dubious-ownership
protection is globally suppressed.

**Done when:** bootstrap defaults are sandboxed and approval-requiring, project
servers require explicit trust, Git ownership protection remains active, risky
profiles/aliases are clearly named opt-ins, and the installer shows the exact
security delta before enabling one.

## P1 — fix before unattended use

### 7. Fail the Ubuntu bootstrap when privilege acquisition or required packages fail

`min_system.sh` and `extra_install.sh` accept only root or already-working
non-interactive `sudo -n`; on a normal fresh terminal they can skip required
package work while the parent flow continues. Acquire sudo once through a clear
interactive preflight (or stop), propagate failures, and finish with a manifest
of required commands/versions that must all verify.

### 8. Correct generated Git editor, merge-tool, and diff-tool commands

`ubuntu/gitconfig.sh` double-quotes `$MERGED`, `$LOCAL`, and `$REMOTE`, so the
shell expands them while configuring Git rather than when Git invokes the tool.
It also uses `code --new-window -wait`. Quote placeholders for deferred
expansion, use the supported `--wait` option, and add an isolated-config test
that opens a fake tool and verifies all argument paths.

### 9. Select compatible accelerator packages instead of hard-coding cu126

`ubuntu/install_dl_frameworks.sh` detects `nvidia-smi` but installs from the
PyTorch `cu126` channel regardless of the detected environment. Define a tested
driver/toolkit/framework compatibility matrix, choose from it explicitly, pin
versions/hashes, and verify an actual tensor operation before reporting success.

### 10. Pin and verify every downloaded executable or installer

Several active flows pipe remote content into a shell, clone a mutable branch,
use a mutable container tag, or execute an unverified release binary. Replace
these with immutable versions/digests and signature or checksum validation.
Record provenance in logs and fail closed. Generate dependency locks for pip,
conda, npm, and container inputs where applicable.

### 11. Replace the bundled undocumented Minikube binary

`ubuntu/minikube-linux-amd64` is a 48.6 MB ELF executable committed without a
version/provenance document or adjacent checksum record. Remove opaque binaries
from Git, install a pinned upstream release for the detected architecture, and
verify its publisher checksum/signature before execution.

### 12. Repair and modernize Kubernetes installation

`ubuntu/kubectl.sh` uses `~/etc` instead of `/etc`, concatenates a redirection
target with `sudo apt-get update`, uses ineffective `sudo echo >>`, and targets
the obsolete `kubernetes-xenial` repository/apt-key flow. Replace it with the
current signed-keyring upstream procedure, architecture/distro validation, and
an idempotent version check.

### 13. Make the dev container match real CPU/GPU images

`.devcontainer/devcontainer.json` forces `--gpus all`, uses mutable
`sytelus/gpu-devbox:latest`, and points Python/`VIRTUAL_ENV` to
`/opt/nanugpt-venv`, which neither Dockerfile creates. Provide separate CPU and
GPU configurations (or a working feature switch), pin the image digest, use the
actual interpreter, and test create/reopen on GPU and non-GPU hosts.

### 14. Add native-platform CI and disposable integration tests

There is no repository CI. The only substantial unit suite targets
`small2zip`; `tests/atari.py` and `tests/cuda.py` are dependency/hardware smoke
scripts with obsolete APIs/typos. Add PowerShell 5.1/7 parsing and unit tests,
Bash lint/unit tests, macOS and Ubuntu idempotence tests, secret/static analysis,
Docker builds, link checks, and opt-in hardware smoke tests. Validate rollback
and interruption for destructive paths.

### 15. Do not disable PDF-reader security updates as a setup default

`windows/utilities.ps1` disables Adobe and Foxit update services/tasks. A manual
future rerun is not a reliable security-update policy. Keep vendor security
updates enabled by default; make any managed-update alternative explicit,
time-bounded, observable, and verified.

### 16. Add an explicit repository license or remove license claims

Container image labels claim `MIT`, but the repository has no license file.
Add the intended license with ownership approval and make all image/package
metadata agree, or remove the unsupported license labels.

## P2 — important correctness and operability

### 17. Give `install_tailscale.py` the correct language, extension, and installer

The file contains shell commands and fails Python parsing at line 2. Rename it
to `.sh`, add a shebang/strict mode, use the current signed upstream repository
instructions, and add it only through a documented opt-in flow.

### 18. Fix Azure mount helper paths and secret storage

`azmount.sh` locates `azmount.yaml` relative to the caller's current directory,
while `cp_dotfiles.sh` copies the executable elsewhere; `azunmount.sh` invokes
`blobfuze2` instead of `blobfuse2`. Resolve configuration relative to an
explicit protected path, validate mode/ownership, prefer managed identity, and
test mount/unmount outside the repository directory.

### 19. Harden shell startup and shared dotfile installation

Fix the `is_vscode_Shell`/`is_vscode_shell` typo, correct ssh-agent reuse so it
does not start/leak a second agent, prevent duplicate WSL alias appends, and
platform-filter Linux-only helpers instead of copying them into macOS
`~/.local/bin`. Test repeated runs in clean Bash and Zsh homes.

### 20. Fix narrower broken helpers

- `git_status.py` must handle an empty directory without `max()` on an empty
  sequence.
- `kill_vscode_srv.sh` must use the intended `.vscode-server` path and require a
  confirmed exact target before deletion.
- `install_cuda12.4.sh` must not install both a versioned toolkit and the generic
  moving `cuda-toolkit` package.
- `install_docker.sh` must not strand the orchestrator inside `newgrp docker`.
- `prepare_new_box.sh` must refer to the existing `wsl_prep.md`.
- `torch_info.py` should call its defined basic-info collector.

Add a focused regression check for each repaired helper.

### 21. Replace hard-coded local documentation links

`mac/README.md` links to `/home/shitals/GitHubSrc/pcprep/...`, which is invalid
in other clones and in this Windows checkout. Convert them to repository-relative
links and include Markdown link validation in CI.

### 22. Make smoke tests current and self-describing

Correct the TensorFlow import typo and obsolete Atari/Gym interfaces, declare
their optional dependencies, detect unavailable hardware with an explicit skip,
and separate diagnostic examples from automated pass/fail tests.

