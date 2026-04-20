# macOS Setup Scripts

These scripts build a conservative, re-runnable macOS developer environment for a new Apple Silicon MacBook.

The scope is intentionally narrower than the tutorial in [macos-expert-tutorial.md](./macos-expert-tutorial.md):

- It keeps the high-value developer fixes from the tutorial.
- It avoids highly personal shell customization such as Oh My Zsh, Powerlevel10k, Karabiner remaps, and aggressive Dock or trackpad changes.
- It keeps Python tooling on the Homebrew-managed interpreter rather than touching Apple's system Python.

## Files

- `prepare_new_box.sh`: main entrypoint for a new machine
- `apply_defaults.sh`: reversible macOS preference tweaks for developers
- `revert_defaults.sh`: removes the preferences set by `apply_defaults.sh`
- `apply_dotfiles.sh`: copies shared dotfiles from `ubuntu/` + installs a managed zsh fragment
- `setup_python_ai.sh`: installs the AI Python package set into Homebrew Python
- `verify_setup.sh`: validates the resulting installation
- `Brewfile.core`: curated CLI packages
- `Brewfile.cask`: curated GUI packages
- `requirements-ai.txt`: conservative Python package set for AI development
- `requirements-mlx.txt`: Apple MLX extras layered on top of the PyTorch stack
- Shared repo dotfiles copied/linked into the user's home directory
  - `../ubuntu/.tmux.conf` → `~/.tmux.conf` (copy-if-absent)
  - `../ubuntu/.claude/settings.json` → `~/.claude/settings.json` (copy-if-absent)
  - `../ubuntu/.codex/config.toml` → `~/.codex/config.toml` (copy-if-absent)
- `dotfiles/`
  - `pcprep-shell.zsh` → `~/.config/pcprep/pcprep-shell.zsh` (rewritten every run) and sourced from `~/.zshrc` via a fenced managed block

## Usage

Run the full bootstrap:

```bash
bash mac/prepare_new_box.sh
```

Re-run only the Homebrew Python AI package refresh:

```bash
bash mac/setup_python_ai.sh
```

Verify the final machine state:

```bash
bash mac/verify_setup.sh
```

Revert the developer defaults managed by this repo:

```bash
bash mac/revert_defaults.sh
```

## Common environment flags

All `INSTALL_*` flags below default to `1` (enabled). Miniconda is also
installed by default, but it remains dormant unless you explicitly activate it.
Set any flag to `0` to skip that part of the bootstrap.

### Core bootstrap
- `NO_NET=1`: skip network-backed installs and only apply local configuration
- `INSTALL_GUI_APPS=0`: skip iTerm2, VS Code, and Rectangle
- `INSTALL_DOCKER=0`: skip Docker Desktop
- `INSTALL_GITHUB_CLI=0`: skip the GitHub CLI install
- `INSTALL_GITHUB_COPILOT_CLI=0`: skip the GitHub Copilot CLI install
- `INSTALL_CODEX_APP=0`: skip the Codex desktop app install
- `INSTALL_CLAUDE_APP=0`: skip the Claude desktop app install
- `INSTALL_AI_ENV=0`: skip installing AI Python packages into Homebrew Python
- `INSTALL_MINICONDA=0`: skip the default Miniconda install into `~/miniconda3`
- `INSTALL_CODEX=0`: skip the Codex CLI install
- `INSTALL_CLAUDE_CODE=0`: skip the Claude Code install
- `ENABLE_FIREWALL=0`: leave the macOS firewall unchanged
- `ENABLE_TOUCH_ID_FOR_SUDO=0`: leave sudo authentication unchanged
- `APPLY_MACOS_DEFAULTS=0`: skip the `defaults write` pass in `apply_defaults.sh`
- `APPLY_DOTFILES=0`: skip copying the shared dotfiles and the managed zsh fragment

### Developer extras (all default to `1`)
- `INSTALL_EXTRA_CLIS=0`: skip `ncdu`, `sysbench`, `iperf3`, and AppCleaner
- `INSTALL_LLAMA_CPP=0`: skip the `llama.cpp` CLI
- `INSTALL_GO=0`: skip the Go toolchain
- `INSTALL_OLLAMA=0`: skip the Ollama CLI (formula only — no auto-start daemon)
- `INSTALL_TAILSCALE=0`: skip the Tailscale CLI (formula only — no auto-start daemon)
- `INSTALL_RUST=0`: skip `rustup` and the stable Rust toolchain
- `INSTALL_DEV_FONTS=0`: skip JetBrains Mono, MesloLG Nerd Font, and Fira Code
- `INSTALL_FIREFOX=0`: skip Firefox
- `INSTALL_CHROME=0`: skip Google Chrome (installs the persistent Keystone updater)
- `INSTALL_MLX=0`: skip adding `mlx` + `mlx-lm` to Homebrew Python

Example opt-out run:

```bash
INSTALL_MINICONDA=0 bash mac/prepare_new_box.sh
```

## Apple vs Homebrew Tools

These scripts install Homebrew tools alongside Apple's built-ins. They do not
replace `/bin/*` or `/usr/bin/*`, so you can always call either toolchain
explicitly when you want to.

### Bash

- macOS still defaults to `zsh` as the login shell. This repo does not call
  `chsh` or force Bash as your login shell.
- Apple Bash is always available as `/bin/bash`.
- Homebrew Bash is installed side-by-side as `$(brew --prefix)/bin/bash`.
- Running these scripts does **not** replace the shell you are currently in.
  `brew shellenv` changes `PATH`; it does not swap the active process from
  Apple Bash to Homebrew Bash.
- After `prepare_new_box.sh` runs, new login shells source pcprep's managed
  shellenv from `~/.config/pcprep/macos-shellenv.sh`, which runs
  `brew shellenv` and puts Homebrew's `bin/` ahead of the system paths.
- Practical result:
  - your login shell still stays `zsh` unless you explicitly run `chsh`
  - if you later type plain `bash` in a new terminal, it will usually launch
    Homebrew Bash because that `bash` now resolves first on `PATH`
  - if you explicitly run `/bin/bash`, you still get Apple's Bash
- Scripts with `#!/bin/bash` still use Apple's Bash. Scripts with
  `#!/usr/bin/env bash` use whichever `bash` is first on `PATH`.

Check which one you are using:

```bash
type -a bash
bash --version
/bin/bash --version
"$(brew --prefix)/bin/bash" --version
```

Use one explicitly:

```bash
/bin/bash
"$(brew --prefix)/bin/bash"
```

Make Homebrew Bash your login shell:

```bash
echo "$(brew --prefix)/bin/bash" | sudo tee -a /etc/shells
chsh -s "$(brew --prefix)/bin/bash"
```

Switch back to Apple's Bash login shell:

```bash
chsh -s /bin/bash
```

### Python

- This repo installs AI packages into Homebrew `python@3.12`.
- It intentionally does **not** install into Apple's system-managed Python.
- The explicit Homebrew interpreter is `$(brew --prefix)/bin/python3.12`.
- On macOS releases that still ship Apple's Python 3 launcher, the explicit
  Apple-managed interpreter is `/usr/bin/python3`.
- The repo does not force unversioned `python`, `python3`, `pip`, or `pip3` to
  point at Homebrew Python by default.

Check which Python you are using:

```bash
type -a python3 python3.12
python3.12 --version
/usr/bin/python3 --version 2>/dev/null || true
"$(brew --prefix)/bin/python3.12" --version
```

Use one explicitly:

```bash
if [ -x /usr/bin/python3 ]; then /usr/bin/python3; fi
"$(brew --prefix)/bin/python3.12"
```

If you want plain `python`, `python3`, `pip`, and `pip3` to resolve to
Homebrew `python@3.12` in your shell:

```bash
export PATH="$(brew --prefix)/opt/python@3.12/libexec/bin:$PATH"
```

### Unix Tools: BSD vs GNU

- macOS ships BSD userland tools such as `/usr/bin/sed`, `/usr/bin/grep`,
  `/usr/bin/find`, and `/usr/bin/tar`.
- This repo installs GNU replacements side-by-side via Homebrew.
- By default, the GNU variants are available under names like `gsed`, `ggrep`,
  `gfind`, `gtar`, `gawk`, `gls`, `gdu`, and `greadlink`.
- The repo intentionally does **not** put GNU `gnubin` directories ahead of the
  BSD tools on `PATH`, because that can break stock macOS scripts that expect
  BSD behavior.

Check what your shell resolves today:

```bash
type -a sed grep find tar ls bash python3
```

Use the GNU tools explicitly without changing PATH:

```bash
gsed
ggrep
gfind
gtar
gawk
gls
```

If you want GNU names like `sed`, `grep`, `find`, `tar`, and `ls` to win in
your shell:

```bash
export PATH="$(brew --prefix)/opt/coreutils/libexec/gnubin:$PATH"
export PATH="$(brew --prefix)/opt/findutils/libexec/gnubin:$PATH"
export PATH="$(brew --prefix)/opt/gnu-sed/libexec/gnubin:$PATH"
export PATH="$(brew --prefix)/opt/gnu-tar/libexec/gnubin:$PATH"
export PATH="$(brew --prefix)/opt/grep/libexec/gnubin:$PATH"
export PATH="$(brew --prefix)/opt/gawk/libexec/gnubin:$PATH"
```

## Notes on intentional omissions

- GNU tools are installed, but not forced ahead of BSD tools in `PATH`. That keeps the machine safer for stock macOS scripts while still making GNU variants available.
- Miniconda is installed by default into `~/miniconda3`, but still left off PATH so Homebrew Python 3.12 plus `uv` remain the default toolchain.
- When Miniconda is present, new shells get helper functions from pcprep's managed shellenv: `condaon` activates conda base (or `condaon ENV_NAME` activates a named environment) and `condaoff` fully deactivates conda again. This keeps conda available on demand without running `conda init`.
- AI Python packages are installed into the Homebrew-managed interpreter, not into Apple's system Python and not into a repo-owned `~/.venvs/...` environment.
- Ollama and Tailscale install their **CLI formulas only**, not the GUI casks. The casks ship login items that auto-start background daemons; the formulas leave daemon lifecycle in the user's hands so the idle battery cost is only paid when the services are actually in use. Start them with `ollama serve` / `sudo brew services start tailscale` as needed.
- Oh My Zsh, Powerlevel10k, and the usual `.zshrc` rewrites are not performed. The scripts intentionally do not own the user's shell rc.
- No automated Safari tweaks, FileVault toggles, or Setup Assistant changes — all are TCC-protected or pre-login and require manual confirmation in System Settings.
- If you keep the defaults `ENABLE_TOUCH_ID_FOR_SUDO=1` and `ENABLE_FIREWALL=1`, both changes are reversible. Remove the `pam_tid.so` line from `/etc/pam.d/sudo_local` to undo Touch ID for sudo, and run `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off` to turn the firewall back off.
- The managed zsh fragment installed by `apply_dotfiles.sh` is fully reversible: delete `~/.config/pcprep/pcprep-shell.zsh` and remove the `>>> pcprep macos zshrc >>>` / `<<< pcprep macos zshrc <<<` block from `~/.zshrc`. The shared `~/.tmux.conf`, `~/.claude/settings.json`, and `~/.codex/config.toml` copies are copy-if-absent and never overwrite existing user edits, so they are effectively opt-in for already-configured machines.

See `todo.md` for the candidate list that drove the current defaults and `unimplemented.md` for the full audit of what the tutorial recommends but these scripts deliberately skip.
