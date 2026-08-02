# Security and safety

## Baseline rule

Assume every bootstrap or administrative script can change a real machine.
Read the source, use a backup, test in an isolated environment, and give the
script only the privilege it needs. The initial P0 findings have source fixes
and focused tests; [TODO.md](../TODO.md) records remaining native-integration
and supply-chain work.

## Safety controls added in the remediation pass

- `small2zip` uses exclusive per-target lock ownership before archive or delete.
- Docker data migration has a true no-write dry-run, containment rejection,
  transactional configuration, rollback, and conclusive verification.
- CUDA apt repair edits only matching lines/stanzas and restores backups if apt
  validation fails.
- CIFS reads secrets outside argv, atomically creates root-only credentials,
  edits fstab idempotently, and rolls back a failed mount.
- SSH known-host verification is enabled.
- Codex defaults use workspace sandboxing and approvals; Claude project MCP
  auto-enable, unsafe agent aliases, and Git's global ownership bypass are gone.

Focused local tests do not replace a disposable native-system exercise. Do not
make the first real Docker migration, apt edit, or mount against irreplaceable
state; that integration coverage is deferred in TODO item 14.

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
- Keep the installed Azure config at mode 0600 and use managed identity; the
  helper refuses plaintext account-key mode.

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

The shared defaults now require agent approval/workspace sandboxing, filter
secret-named environment variables, require explicit project MCP trust, and
preserve Git's dubious-ownership protection. Keep any future full-access mode
outside the copied default and opt in only for a specific trusted task.

## What this review established

The review parsed PowerShell and Bash sources, JSON and TOML, the bookmarklet
JavaScript, and Python syntax; inspected every text/configuration file; and
identified and removed the bundled ELF binary. Tailscale is now correctly named
shell source. Focused tests exercised only temporary data: the two-process
archive lock, Docker dry-run, Git tool arguments, and helper checks. No installer,
package-manager change, container build, service migration, registry operation,
or real mount was run.

Static parsing can detect malformed source and unsafe logic. It cannot validate
vendor availability, package compatibility, native OS behavior, idempotence,
rollback, or hardware-dependent results. Those require disposable native test
environments and automated integration coverage.
