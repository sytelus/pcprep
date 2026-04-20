# macOS Setup Scripts

Re-runnable bootstrap for a macOS developer machine. The `mac/` scripts install
Homebrew-managed tools, shared dotfiles, a Homebrew Python + `uv` AI stack,
conservative Git defaults, and a small set of macOS defaults without taking
over the whole machine.

## Before You Run It

- macOS only.
- `~/.ssh` must already exist with your keys and config.
- Internet is required unless you run with `NO_NET=1`.
- The bootstrap checks global `git user.name` / `git user.email` early in the
  run and only prompts if either is missing. Any entered values are written
  immediately so reruns do not ask again. You can preseed them with
  `user_name=... user_email=...`.
- When sudo is available, the bootstrap prompts once up front and keeps that
  sudo session alive for the rest of the run.

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

Refresh only the Homebrew Python AI packages:

```bash
bash mac/setup_python_ai.sh
```

Verify the current machine state:

```bash
bash mac/verify_setup.sh
```

## What It Sets Up

- Homebrew core CLI tools from [Brewfile.core](/home/shitals/GitHubSrc/pcprep/mac/Brewfile.core:1)
- Optional GUI apps from [Brewfile.cask](/home/shitals/GitHubSrc/pcprep/mac/Brewfile.cask:1)
- Shared dotfiles and helper scripts via [apply_dotfiles.sh](/home/shitals/GitHubSrc/pcprep/mac/apply_dotfiles.sh:1)
- Homebrew Python 3.12 AI environment via [setup_python_ai.sh](/home/shitals/GitHubSrc/pcprep/mac/setup_python_ai.sh:1)
- Conservative macOS defaults via [apply_defaults.sh](/home/shitals/GitHubSrc/pcprep/mac/apply_defaults.sh:1)
- Final validation via [verify_setup.sh](/home/shitals/GitHubSrc/pcprep/mac/verify_setup.sh:1)

Normal runs end with:

- `tmux`, `zellij`, and `screen` available on `PATH`
- Apple Clang C/C++ compilation working, plus `cmake`, `ninja`, and `pkg-config`
- Azure CLI dynamic extension installs preconfigured under `~/.azure/cliextensions`
- Homebrew Python AI packages installed into `python@3.12`
- Miniconda installed by default, but left dormant and off `PATH`

## Feature Flags

Common toggles:

| Flag | Default | Effect |
|---|---:|---|
| `NO_NET` | `0` | Skip network-backed installs and run only local steps |
| `SKIP_BREW_UPDATE` | `0` | Reuse existing Homebrew metadata |
| `INSTALL_GUI_APPS` | `1` | Install the GUI Brewfile (`iTerm2`, VS Code, Rectangle) |
| `INSTALL_DOCKER` | `1` | Install Docker Desktop |
| `INSTALL_GITHUB_COPILOT_CLI` | `1` | Install the GitHub Copilot CLI cask |
| `INSTALL_CODEX_APP` | `1` | Install Codex.app |
| `INSTALL_CLAUDE_APP` | `1` | Install Claude.app |
| `INSTALL_CODEX` | `1` | Install the Codex CLI npm package |
| `INSTALL_CLAUDE_CODE` | `1` | Install the Claude Code npm package |
| `INSTALL_AI_ENV` | `1` | Install the Homebrew Python AI package set |
| `INSTALL_MINICONDA` | `1` | Install Miniconda into `~/miniconda3` without `conda init` |
| `USE_POWERLEVEL10K_PROMPT` | `0` | Install Powerlevel10k and use the managed compact Powerlevel10k zsh prompt |
| `APPLY_MACOS_DEFAULTS` | `1` | Apply the managed macOS defaults |
| `APPLY_DOTFILES` | `1` | Install the managed bash/zsh fragments and copy shared dotfiles |
| `ENABLE_FIREWALL` | `1` | Enable the macOS application firewall |
| `ENABLE_FIREWALL_STEALTH` | `0` | Also enable firewall stealth mode |
| `ENABLE_TOUCH_ID_FOR_SUDO` | `1` | Configure Touch ID for `sudo` where supported |
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
| `INSTALL_FIREFOX` | Install Firefox |
| `INSTALL_CHROME` | Install Google Chrome |
| `INSTALL_LLAMA_CPP` | Install `llama.cpp` |
| `INSTALL_MLX` | Install MLX extras on Apple Silicon; skipped automatically on Intel Macs |

Other supported path/config overrides:

- `MINICONDA_DIR=/custom/path`
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

- Installed into Homebrew `python@3.12`, not Apple’s Python
- Includes notebook/data-science basics, TensorFlow/Keras, PyTorch, TensorBoard,
  and the mainstream LLM tooling stack
- MLX is treated as an Apple-Silicon-only layer on top of that stack

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
