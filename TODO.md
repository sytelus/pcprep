# Remaining work

The 2026-07-29 remediation pass implemented the original items except 10, 14,
15, and 22, which were explicitly deferred. Completed work is recorded below
so the safety decisions and validation limits remain auditable.

## P1 — deferred by request

### 10. Pin and verify every downloaded executable or installer

Several active flows still pipe remote content to a shell, clone mutable branch
heads, use mutable container tags, or install unlocked language dependencies.
Pin versions/digests, verify signatures or independently authenticated hashes,
record provenance, generate dependency locks, and fail closed.

The new Minikube installer is already pinned and checksum-verified, Kubernetes
and Tailscale use signed repositories, and the Windows Miniconda flow verifies
Authenticode. Those focused fixes do not close the broader repository task.

### 14. Add native-platform CI and disposable integration tests

Add PowerShell 5.1/7 validation, Bash lint/unit tests, macOS and Ubuntu
idempotence tests, secret/static analysis, CPU/GPU container builds, Markdown
link checking, and opt-in hardware tests. Exercise rollback/interruption for
Docker migration, apt repair, CIFS, and other destructive or privileged paths.

Local tests now cover the `small2zip` two-process lock, Docker migration dry-run
non-mutation/containment, Git tool commands, and narrower helpers. Native
rootful/rootless migrations, apt changes, mounts, installers, macOS, CUDA, and
container creation were not executed on this Windows host.

### 15. Keep PDF-reader security updates enabled by default

`windows/utilities.ps1` still disables Adobe and Foxit update services/tasks.
Keep vendor security updates enabled unless a documented, observable,
time-bounded managed-update replacement exists.

## P2 — deferred by request

### 22. Make smoke tests current and self-describing

Update `tests/atari.py` and `tests/cuda.py`: correct the TensorFlow import typo
and obsolete Atari/Gym interfaces, declare optional dependencies, report
hardware-dependent skips explicitly, and separate examples from automated
pass/fail tests.

## Privacy decisions

### P1. Decide whether to rewrite author identity in Git history

Git history contains the owner's real name plus personal and corporate email
addresses. Removing those values from current files cannot remove commit
metadata already published. If disclosure is unwanted, coordinate a history
rewrite and force-push with every clone/fork owner, then rotate or abandon old
references. See [Privacy and secret scan](docs/PRIVACY_AND_SECRETS.md).

### P2. Parameterize remaining personal workstation defaults

Active configuration still contains personal login names, a host name, absolute
home paths, project/organization identifiers, and a private DNS address. Decide
which public GitHub/Docker identity is intentional, then replace workstation-only
values with environment variables or documented placeholders.

## Completed on 2026-07-29

| Original item | Implemented outcome | Validation performed here |
| ---: | --- | --- |
| 1 | Added exclusive per-archive lock tokens and ownership checks before partial cleanup, publish, and delete | Real two-process Windows regression passed |
| 2 | Rebuilt Docker data migration with no-write dry-run, path containment checks, fail-closed services/config, count/byte/rsync verification, rollback, and recoverable old data | Bash parse and isolated no-mutation/containment tests passed; native migration remains under item 14 |
| 3 | CUDA apt repair now backs up and edits only matching `.list` lines or Deb822 stanzas, validates the key, and rolls back on apt failure | Bash parse; privileged apt integration remains under item 14 |
| 4 | Restored normal SSH known-host verification | Configuration inspection and regression scan passed |
| 5 | CIFS now reads secrets silently/stdin, validates inputs, writes root-only credentials atomically, updates fstab idempotently, uses least-privilege modes, and rolls back on mount failure | Bash parse and invalid-input tests passed; real mount remains under item 14 |
| 6 | Codex defaults now require approval/workspace sandboxing, and project MCP auto-enable and Git safe-directory bypass were disabled; explicitly named agent bypass aliases remain available for intentional use | TOML/JSON parsing, Bash argument-forwarding tests, DOSKEY loading, and installed CLI flag checks passed |
| 7 | Ubuntu setup explicitly acquires sudo, propagates apt/install failures, and verifies a required command manifest | Bash parse and static flow inspection; native bootstrap remains under item 14 |
| 8 | Git editor/merge/diff commands preserve deferred path variables and use `--wait` | Isolated fake-`code` argument test passed |
| 9 | PyTorch selection uses a reviewed driver/wheel matrix (`cu126`, `cu130`, `cu132`, or CPU) and verifies a real tensor operation | Bash parse; package/GPU execution remains under item 14 |
| 11 | Removed the 48.6 MB opaque Minikube binary and added a v1.38.1 architecture-specific installer with upstream release checksums | Binary deletion verified; installer parsed; network install not run |
| 12 | Replaced obsolete apt-key/xenial commands with the signed `pkgs.k8s.io` minor-version repository | Bash parse; apt install not run |
| 13 | Default dev container now builds the CPU Dockerfile with `/opt/conda/bin/python`; an explicit GPU config builds the GPU Dockerfile and requires CUDA | JSON parsing and path checks; Docker was unavailable for create/reopen tests |
| 16 | Removed unsupported MIT image labels and license claim | Repository scan finds no remaining MIT/license claim |
| 17 | Replaced shell-in-`.py` Tailscale file with a strict-mode, distro-aware signed-repository installer | Bash/Python parsing confirms correct language split |
| 18 | Azure helpers resolve a protected user config, require managed identity, verify ownership/mode and mount state, and use the correct unmount command | Bash parse and helper regression scan passed |
| 19 | Fixed shell variable case, SSH-agent reuse, WSL alias idempotence, and macOS platform filtering | Bash parse and helper regression tests passed |
| 20 | Fixed empty Git directory, exact VS Code server target/confirmation, CUDA package drift, blocking `newgrp`, WSL doc name, and missing torch basic info | Focused helper regression tests passed |
| 21 | Converted macOS README links to repository-relative paths | Local Markdown link check passed |
