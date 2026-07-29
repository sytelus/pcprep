# Security and safety

## Baseline rule

Assume every bootstrap or administrative script can change a real machine.
Read the source, use a backup, test in an isolated environment, and give the
script only the privilege it needs. The current repository has known P0 issues;
[TODO.md](../TODO.md) is part of the operating documentation, not an optional
future-work list.

## Current hard blockers

Do not use these paths for their intended state-changing operation until the
corresponding P0 is fixed and tested:

- concurrent `utils/small2zip.py` runs against the same target;
- `ubuntu/docker/cpu-devbox/docker-move-data.sh`, including `--dry-run`;
- `ubuntu/fix_cuda_repo.sh` on a machine where `/etc/apt/sources.list` matters;
- `ubuntu/mount_cifs.sh` for real credentials or persistent mounts;
- the default `ubuntu/.ssh/config` as a global SSH configuration.

The Codex/Claude/shell configurations copied by the Ubuntu and macOS flows also
contain broad trust and approval bypasses. They must become explicit opt-ins
rather than new-machine defaults.

## Downloads and supply chain

Multiple scripts download and execute shell installers, package-manager output,
Git branch heads, or release binaries. Examples include Homebrew, Miniconda or
Miniforge, rustup, Claude Code, Codex, NVM, Oh My Zsh, AzCopy, Zellij, and ML
packages. Docker images use mutable tags and most language dependencies are not
locked.

For each external artifact:

1. pin an immutable version or digest;
2. download to a temporary file rather than piping directly to a shell;
3. verify a publisher signature or a checksum obtained through an independent,
   authenticated channel;
4. inspect unexpected redirects and content type;
5. record the verified version in the run log; and
6. fail closed when verification is unavailable.

The Windows Miniconda flow already demonstrates publisher verification via
Authenticode. Apply an equivalent explicit trust decision elsewhere.

## Credentials and identity

- Never accept passwords, account keys, or tokens as command-line arguments;
  they can leak through shell history and process listings.
- Create credential files with restrictive permissions before writing secrets.
- Prefer OS keychains, managed identities, SSH agents, and short-lived tokens.
- Do not copy private SSH material without explicit confirmation and destination
  ownership/permission checks.
- Preserve SSH host-key verification. Pre-populate known hosts through a trusted
  channel instead of using `StrictHostKeyChecking no` or `/dev/null` storage.
- Do not commit populated versions of `ubuntu/azmount.yaml` or other local
  credential material.

## Destructive and privileged operations

The following categories require an explicit review of targets immediately
before execution:

- archive-then-delete (`small2zip`), copy/move/mirror (`copyallfiles.bat`), and
  Docker data-root migration;
- Docker prune, CUDA/Miniconda uninstall, submodule deletion, VS Code server
  cleanup, and shell aliases such as force clean/revert;
- apt, Homebrew, WinGet, npm, pip, conda, registry, firewall, service, power,
  mount, `/etc`, and macOS `defaults` changes;
- `sudo`, UAC/elevated child processes, root containers, and host mounts.

A safe destructive workflow resolves and displays exact source/destination
paths, rejects dangerous containment relationships, checks free space and active
writers, backs up configuration, uses atomic publication, preserves a rollback
source, verifies counts and bytes, and deletes only after conclusive success.
Failure or missing evidence must stop the operation.

## Agent and Git safety

The shared dotfiles currently include approval-bypassing agent aliases,
full-access Codex defaults, automatic project MCP enablement, and
`GIT_TEST_ASSUME_ALL_SAFE=1`. These settings expand the consequences of a
malicious repository or mistaken command. Use a sandboxed, approval-requiring
profile by default; enable broader access per task and per trusted repository.
Do not globally suppress Git's dubious-ownership protection.

## What this review established

The review parsed PowerShell and Bash sources, JSON and TOML, the bookmarklet
JavaScript, and Python syntax; inspected every text/configuration file; and
identified the bundled ELF binary and its repository role. The file named
`ubuntu/install_tailscale.py` failed Python parsing because it is actually shell
source. No installer, setup script, package manager, container build, service
operation, registry operation, mount, or destructive tool was run.

Static parsing can detect malformed source and unsafe logic. It cannot validate
vendor availability, package compatibility, native OS behavior, idempotence,
rollback, or hardware-dependent results. Those require disposable native test
environments and automated integration coverage.

