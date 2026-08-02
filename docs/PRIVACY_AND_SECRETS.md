# Privacy and secret scan

## Result

No active credential, private key, cloud connection string, or recognizable
AWS/GitHub/Slack/OpenAI token was found in the current working tree by the
2026-07-29 pattern scan. The historical Azure mount configuration matched a
secret-shaped field, but every endpoint/account/key/container value in that
commit was a `YOUR_...` placeholder rather than a credential.

This is not proof that no secret has ever existed: pattern scanning cannot
recognize every vendor format or high-entropy value, and the removed historical
Minikube binary was treated as an opaque upstream executable rather than
decompiled.

## Confirmed personal or organizational information

### Git history

Commit metadata exposes:

- the owner's full name;
- a personal Gmail address; and
- a Microsoft corporate email address.

The addresses are intentionally not repeated here. They remain recoverable from
every existing commit and remote clone even if future commit identity changes.
Removal requires a coordinated history rewrite and force-push; ordinary file
edits cannot remove them.

### Current tracked files

| Information | Locations | Exposure |
| --- | --- | --- |
| Login/user identifiers (`shitals`, `bonete61`) | `windows/aliases.doskey`, `windows/WindowsTerminal/settings.json`, `ubuntu/.config/terminator/config`, `ubuntu/.bash_aliases`, `ubuntu/gitclones.sh` | Personal login and resource naming |
| Public account identity (`sytelus`) | repository/setup URLs, Git clone lists, Docker image defaults/labels/docs | Links the repository, GitHub account, and Docker Hub namespace |
| Host and absolute home paths | `ubuntu/.config/terminator/config`, `windows/WindowsTerminal/settings.json`, `archived/ubuntu/old_wsl_setup.sh` | Local username, host name, directory layout, and project names |
| Employer/internal project references | commented `vso/msresearch/Theseus` aliases in `ubuntu/.bash_aliases` | Organizational affiliation and project naming |
| Private DNS address | `ubuntu/wsl_vpn.py` (`10.50.10.50`) | Internal network configuration; not Internet-routable but still environment-specific |
| Personal project/repository list | `ubuntu/gitclones.sh` and Terminator working directories | Interests, project names, and account relationships |

Some of this may be intentionally public branding. Parameterize or remove the
workstation-only values if the repository will be shared beyond the intended
audience.

## Security improvements made in this pass

- CIFS passwords are no longer accepted as command arguments.
- Azure mounting defaults to managed identity and a mode-0600 user config;
  plaintext account-key configuration is refused.
- SSH host identity verification is enabled.
- Codex/Claude/Git defaults no longer bypass approval, sandbox, project-server,
  environment-secret filtering, or dubious-ownership protections.
- The undocumented binary was removed and replaced by a pinned checksum-verified
  upstream installer.

## Scan method and limits

The current tree was searched for private-key headers, common cloud/token
prefixes, connection strings, password/key assignments, email addresses,
absolute user paths, known usernames, host/project terms, and IP addresses. Git
history was searched for the credential-pattern families, and unique author
identities were inspected. Matches were classified manually so placeholders,
documentation examples, public IP probes, and loopback/private examples were
not reported as credentials.

Recommended follow-up is a dedicated entropy-aware scanner in the deferred CI
item, plus provider-side secret scanning on the remote host. If any real secret
is later found, revoke/rotate it first; deleting it from Git is not sufficient.
