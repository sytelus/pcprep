# macOS Setup Scripts

Re-runnable bootstrap for a macOS developer machine. The `mac/` scripts install
Homebrew-managed tools, shared dotfiles, a `uv`-managed `main` Python
environment based on Homebrew Python, conservative Git defaults, and a small
set of macOS defaults without taking over the whole machine.

## Before You Run It

- macOS only.
- `~/.ssh` must already exist with your keys and config.
- Internet is required unless you run with `NO_NET=1`.
- The bootstrap checks global `git user.name` / `git user.email` early in the
  run and only prompts if either is missing. Any entered values are written
  immediately so reruns do not ask again. You can preseed them with
  `user_name=... user_email=...`.
- When sudo is available, the bootstrap prompts once up front and keeps that
  sudo session alive for the rest of the run. By default it also sets the
  system-wide sudo credential timeout to 30 minutes through
  `/etc/sudoers.d/pcprep-timestamp-timeout`.
- Each run writes a full log to `~/Library/Logs/pcprep/prepare_new_box.<timestamp>.log`
  and refreshes `~/Library/Logs/pcprep/prepare_new_box.latest.log`.

## Main Commands

Normal bootstrap:

```bash
bash mac/prepare_new_box.sh
```

Preseed Git identity:

```bash
user_name="Your Name" user_email="you@example.com" bash mac/prepare_new_box.sh
```

Skip Miniconda:

```bash
INSTALL_MINICONDA=0 bash mac/prepare_new_box.sh
```

Enable the managed compact Powerlevel10k zsh prompt:

```bash
USE_POWERLEVEL10K_PROMPT=1 bash mac/prepare_new_box.sh
```

Local-only rerun:

```bash
NO_NET=1 bash mac/prepare_new_box.sh
```

Refresh only the managed `main` Python environment:

```bash
bash mac/setup_python_ai.sh
```

Verify the current machine state:

```bash
bash mac/verify_setup.sh
```

## What It Sets Up

- Homebrew core CLI tools from [Brewfile.core](/home/shitals/GitHubSrc/pcprep/mac/Brewfile.core:1)
- Codex / Claude / Copilot AI tools are installed immediately after the core CLI bundle so they are available early for debugging later setup failures
- Optional GUI apps from [Brewfile.cask](/home/shitals/GitHubSrc/pcprep/mac/Brewfile.cask:1)
- Shared dotfiles and helper scripts via [apply_dotfiles.sh](/home/shitals/GitHubSrc/pcprep/mac/apply_dotfiles.sh:1)
- Managed `main` Python environment based on Homebrew Python 3.12 via [setup_python_ai.sh](/home/shitals/GitHubSrc/pcprep/mac/setup_python_ai.sh:1)
- Conservative macOS defaults via [apply_defaults.sh](/home/shitals/GitHubSrc/pcprep/mac/apply_defaults.sh:1)
- Final validation via [verify_setup.sh](/home/shitals/GitHubSrc/pcprep/mac/verify_setup.sh:1)

Normal runs end with:

- `tmux`, `zellij`, and `screen` available on `PATH`
- Apple Clang C/C++ compilation working, plus `cmake`, `ninja`, and `pkg-config`
- Azure CLI dynamic extension installs preconfigured under `~/.azure/cliextensions`
- Managed `main` Python environment installed at `~/.venvs/main` by default
- Miniconda installed by default, but left dormant and off `PATH`
- Existing manually installed GUI app bundles are reused or adopted instead of causing the bootstrap to fail

## Feature Flags

Common toggles:

| Flag | Default | Effect |
|---|---:|---|
| `NO_NET` | `0` | Skip network-backed installs and run only local steps |
| `SKIP_BREW_UPDATE` | `0` | Reuse existing Homebrew metadata |
| `INSTALL_GUI_APPS` | `1` | Install the GUI Brewfile (`iTerm2`, Ghostty, OpenInTerminal, VS Code, Rectangle) |
| `INSTALL_DOCKER` | `1` | Install Docker Desktop |
| `INSTALL_GITHUB_COPILOT_CLI` | `1` | Install the GitHub Copilot CLI cask |
| `INSTALL_CODEX_APP` | `1` | Install Codex.app |
| `INSTALL_CLAUDE_APP` | `1` | Install Claude.app |
| `INSTALL_CODEX` | `1` | Install the Codex CLI npm package |
| `INSTALL_CLAUDE_CODE` | `1` | Install the Claude Code npm package |
| `INSTALL_AI_ENV` | `1` | Install the managed `main` Python environment |
| `INSTALL_MINICONDA` | `1` | Install Miniconda into `~/miniconda3` without `conda init` |
| `AUTO_ACTIVATE_MAIN` | `1` | Auto-activate the managed `main` Python environment in interactive shells |
| `USE_POWERLEVEL10K_PROMPT` | `0` | Install Powerlevel10k and use the managed compact Powerlevel10k zsh prompt |
| `APPLY_MACOS_DEFAULTS` | `1` | Apply the managed macOS defaults |
| `APPLY_DOTFILES` | `1` | Install the managed bash/zsh fragments and copy shared dotfiles |
| `ENABLE_FIREWALL` | `1` | Enable the macOS application firewall |
| `ENABLE_FIREWALL_STEALTH` | `0` | Also enable firewall stealth mode |
| `ENABLE_TOUCH_ID_FOR_SUDO` | `1` | Configure Touch ID for `sudo` where supported |
| `CONFIGURE_SUDO_TIMESTAMP_TIMEOUT` | `1` | Set a global sudo credential timeout drop-in under `/etc/sudoers.d/` |
| `SUDO_TIMESTAMP_TIMEOUT_MINUTES` | `30` | Minutes before sudo re-prompts system-wide |
| `UPGRADE_NODE_GLOBALS` | `0` | Upgrade Codex CLI / Claude Code instead of install-if-missing |

Optional developer extras, all default `1`:

| Flag | Effect |
|---|---|
| `INSTALL_EXTRA_CLIS` | Install the mac-compatible dormant subset of `ubuntu/extra_install.sh` |
| `INSTALL_OLLAMA` | Install the Ollama formula only, not the GUI cask |
| `INSTALL_TAILSCALE` | Install the Tailscale formula only, not the GUI cask |
| `INSTALL_RUST` | Install Rust through `rustup-init` |
| `INSTALL_GO` | Install Go through Homebrew |
| `INSTALL_DEV_FONTS` | Install JetBrains Mono, MesloLGS Nerd Font, and Fira Code |
| `INSTALL_AZURE_STORAGE_EXPLORER` | Install Azure Storage Explorer for macOS, plus a .NET runtime when `dotnet` is not already present |
| `INSTALL_FIREFOX` | Install Firefox |
| `INSTALL_CHROME` | Install Google Chrome |
| `INSTALL_LLAMA_CPP` | Install `llama.cpp` |
| `INSTALL_MLX` | Install MLX extras on Apple Silicon; skipped automatically on Intel Macs |

Other supported path/config overrides:

- `MINICONDA_DIR=/custom/path`
- `MAIN_VENV_DIR=/custom/path`
- `user_name=...`
- `user_email=...`

`setup_python_ai.sh` also supports:

- `INSTALL_JUPYTER_KERNEL=0`
- `INSTALL_MLX=0`

## Using Key Features

Prompt:

- Default zsh prompt is the plain built-in `%2~ %# `.
- Enable Powerlevel10k with `USE_POWERLEVEL10K_PROMPT=1`.
- If Powerlevel10k glyphs look wrong, set your terminal font to
  `MesloLGS Nerd Font`.
- `USE_POWERLEVEL10K_PROMPT=1` only takes effect automatically when
  `APPLY_DOTFILES=1`, because that is what manages `~/.zshrc`.

Miniconda:

- Installed by default into `~/miniconda3`
- Not added to `PATH`
- `auto_activate_base` is disabled
- Use `condaon` to activate base
- Use `condaon ENV_NAME` to activate a named environment
- Use `condaoff` to fully deactivate conda

Python / AI stack:

- Built from Homebrew `python@3.12`, not Apple’s Python
- Installed into the managed `main` environment at `MAIN_VENV_DIR` instead of into Homebrew’s base interpreter
- Interactive shells auto-activate `main` by default
- Use `mainoff` to return to plain Homebrew Python in the current shell
- Use `mainon` to re-enter `main`
- Set `AUTO_ACTIVATE_MAIN=0` if you do not want `main` auto-activated in new shells
- Includes notebook/data-science basics, TensorFlow/Keras, PyTorch, TensorBoard,
  and the mainstream LLM tooling stack
- Registers a Jupyter kernel named `Python 3.12 (main)`
- `setup_python_ai.sh` and `verify_setup.sh` validate against the repo's requirements files, so the full managed package list is checked rather than a hand-picked subset
- MLX is treated as an Apple-Silicon-only layer on top of that stack

Python switching:

- Default interactive shell: `main` is active unless `AUTO_ACTIVATE_MAIN=0`
- Plain Homebrew Python: run `mainoff`
- Miniconda: run `condaon` or `condaon ENV_NAME`; it deactivates `main` first
- Leave Miniconda: run `condaoff`, then `mainon` if you want `main` back immediately
- Apple Python: use `/usr/bin/python3` explicitly, or `applepy` as a short wrapper

Terminal multiplexers:

- `tmux` is the best default for SSH and remote hosts
- `zellij` is available for a friendlier local UX
- `screen` is present as a compatibility fallback

C/C++ toolchain:

- `prepare_new_box.sh` requires Apple Command Line Tools
- `verify_setup.sh` compiles and runs a tiny C program and a tiny C++ program

Azure CLI:

- `az` and `azcopy` are part of the default CLI set
- The bootstrap enables `extension.use_dynamic_install=yes_without_prompt`
- Run `az login` when you want to authenticate

Git:

- Existing global `user.name` / `user.email` are left alone
- Missing values are prompted for once and written immediately
- `https://github.com/...` remotes are rewritten to SSH so GitHub keys are used automatically

Sudo:

- The bootstrap refreshes the sudo timestamp in the background during long runs
- By default it also sets `timestamp_timeout=30` globally
- Use `CONFIGURE_SUDO_TIMESTAMP_TIMEOUT=0` to leave the system sudo timeout unchanged
- Override the global timeout with `SUDO_TIMESTAMP_TIMEOUT_MINUTES=...`

## Managed Files

Managed under `~/.config/pcprep/`:

- `macos-shellenv.sh`
- `pcprep-shell.bash`
- `pcprep-shell.zsh`
- `pcprep-shell.common.sh`
- `pcprep-p10k.zsh`
- `pcprep-aliases.sh`

Managed blocks are added to:

- `~/.zprofile`
- `~/.zshrc`
- `~/.bashrc`
- `~/.bash_profile`

Copy-if-absent files seeded from `ubuntu/`:

- `~/.inputrc`
- `~/.tmux.conf`
- `~/.claude/settings.json`
- `~/.codex/config.toml`
- helper scripts copied into `~/.local/bin`

## Reversal

- Remove the `pcprep` managed blocks from `~/.zprofile`, `~/.zshrc`,
  `~/.bashrc`, and `~/.bash_profile`
- Delete the managed files under `~/.config/pcprep/`
- Run `bash mac/revert_defaults.sh`
- Remove any copy-if-absent files from your home directory if you no longer
  want them
