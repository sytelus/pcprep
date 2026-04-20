# macOS Setup Scripts

These scripts build a conservative, re-runnable macOS developer environment for a new Apple Silicon MacBook.

The scope is intentionally narrower than the tutorial in [macos-expert-tutorial.md](./macos-expert-tutorial.md):

- It keeps the high-value developer fixes from the tutorial.
- It avoids highly personal shell customization such as Oh My Zsh, Powerlevel10k, Karabiner remaps, and aggressive Dock or trackpad changes.
- It separates system bootstrap from the Python AI environment so repairing one layer does not require rebuilding the other.

## Files

- `prepare_new_box.sh`: main entrypoint for a new machine
- `apply_defaults.sh`: reversible macOS preference tweaks for developers
- `revert_defaults.sh`: removes the preferences set by `apply_defaults.sh`
- `apply_dotfiles.sh`: copies shared dotfiles from `ubuntu/` + installs a managed zsh fragment
- `setup_python_ai.sh`: creates a dedicated AI Python environment under `~/.venvs/`
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

Re-run only the Python environment refresh:

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

Every `INSTALL_*` flag below defaults to `1` (enabled). Set to `0` to skip.

### Core bootstrap
- `NO_NET=1`: skip network-backed installs and only apply local configuration
- `INSTALL_GUI_APPS=0`: skip iTerm2, VS Code, and Rectangle
- `INSTALL_DOCKER=0`: skip Docker Desktop
- `INSTALL_AI_ENV=0`: skip Python AI environment creation
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
- `INSTALL_MLX=0`: skip adding `mlx` + `mlx-lm` to the AI environment

## Notes on intentional omissions

- GNU tools are installed, but not forced ahead of BSD tools in `PATH`. That keeps the machine safer for stock macOS scripts while still making GNU variants available.
- Conda is not installed. The base setup uses Homebrew Python 3.12 plus `uv`, which is simpler and easier to repair on a general-purpose developer laptop.
- Ollama and Tailscale install their **CLI formulas only**, not the GUI casks. The casks ship login items that auto-start background daemons; the formulas leave daemon lifecycle in the user's hands so the idle battery cost is only paid when the services are actually in use. Start them with `ollama serve` / `sudo brew services start tailscale` as needed.
- Oh My Zsh, Powerlevel10k, and the usual `.zshrc` rewrites are not performed. The scripts intentionally do not own the user's shell rc.
- No automated Safari tweaks, FileVault toggles, or Setup Assistant changes — all are TCC-protected or pre-login and require manual confirmation in System Settings.
- If you keep the defaults `ENABLE_TOUCH_ID_FOR_SUDO=1` and `ENABLE_FIREWALL=1`, both changes are reversible. Remove the `pam_tid.so` line from `/etc/pam.d/sudo_local` to undo Touch ID for sudo, and run `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off` to turn the firewall back off.
- The managed zsh fragment installed by `apply_dotfiles.sh` is fully reversible: delete `~/.config/pcprep/pcprep-shell.zsh` and remove the `>>> pcprep macos zshrc >>>` / `<<< pcprep macos zshrc <<<` block from `~/.zshrc`. The shared `~/.tmux.conf`, `~/.claude/settings.json`, and `~/.codex/config.toml` copies are copy-if-absent and never overwrite existing user edits, so they are effectively opt-in for already-configured machines.

See `todo.md` for the candidate list that drove the current defaults and `unimplemented.md` for the full audit of what the tutorial recommends but these scripts deliberately skip.
