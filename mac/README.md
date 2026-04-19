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
- `setup_python_ai.sh`: creates a dedicated AI Python environment under `~/.venvs/`
- `verify_setup.sh`: validates the resulting installation
- `Brewfile.core`: curated CLI packages
- `Brewfile.cask`: curated GUI packages
- `requirements-ai.txt`: conservative Python package set for AI development

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

- `NO_NET=1`: skip network-backed installs and only apply local configuration
- `INSTALL_GUI_APPS=0`: skip iTerm2, VS Code, and Rectangle
- `INSTALL_DOCKER=0`: skip Docker Desktop
- `INSTALL_AI_ENV=0`: skip Python AI environment creation
- `INSTALL_CODEX=0`: skip the Codex CLI install
- `INSTALL_CLAUDE_CODE=0`: skip the Claude Code install
- `ENABLE_FIREWALL=0`: leave the macOS firewall unchanged
- `ENABLE_TOUCH_ID_FOR_SUDO=0`: leave sudo authentication unchanged

## Notes on intentional omissions

- GNU tools are installed, but not forced ahead of BSD tools in `PATH`. That keeps the machine safer for stock macOS scripts while still making GNU variants available.
- Conda is not installed by default. The base setup uses Homebrew Python 3.12 plus `uv`, which is simpler and easier to repair on a general-purpose developer laptop.
- Local-model tools such as Ollama and llama.cpp are not installed by default. They are useful, but they are not required for the specific Python, PyTorch, Codex, and Claude Code workflow this repo is targeting.
- If you keep the defaults `ENABLE_TOUCH_ID_FOR_SUDO=1` and `ENABLE_FIREWALL=1`, both changes are reversible. Remove the `pam_tid.so` line from `/etc/pam.d/sudo_local` to undo Touch ID for sudo, and run `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off` to turn the firewall back off.
