# macOS Setup Scripts

Conservative, re-runnable bootstrap for a new macOS developer machine.

The goal is to install a solid developer baseline without taking over the whole
machine: Homebrew, core CLI and GUI tools, shared dotfiles, conservative Git
defaults, a Homebrew Python + `uv` AI stack, and a small set of macOS defaults.

## Before You Run It

- macOS only.
- `~/.ssh` must already exist with your keys and config. `prepare_new_box.sh`
  exits early if it is missing.
- Internet is required for installs unless you run with `NO_NET=1`.
- The script asks for Git name and email at the start if they are not already
  configured. You can preseed them with `user_name=...` and `user_email=...`.
- When sudo is available, the bootstrap asks up front, then keeps that sudo
  session alive for the rest of the run so later privileged steps do not keep
  re-prompting.

## Main Scripts

- `prepare_new_box.sh`: full bootstrap entrypoint.
- `apply_defaults.sh`: apply the managed macOS preference changes.
- `revert_defaults.sh`: revert the preference changes from `apply_defaults.sh`.
- `apply_dotfiles.sh`: copy shared configs from `ubuntu/` and install the
  managed bash/zsh shell fragments.
- `setup_python_ai.sh`: install the AI Python package set into Homebrew Python.
- `verify_setup.sh`: validate the resulting machine state.

## Usage

Full bootstrap:

```bash
bash mac/prepare_new_box.sh
```

Bootstrap with preseeded Git identity:

```bash
user_name="Your Name" user_email="you@example.com" bash mac/prepare_new_box.sh
```

Bootstrap without Miniconda:

```bash
INSTALL_MINICONDA=0 bash mac/prepare_new_box.sh
```

Local-only rerun:

```bash
NO_NET=1 bash mac/prepare_new_box.sh
```

Refresh only the Homebrew Python AI packages:

```bash
bash mac/setup_python_ai.sh
```

Verify the final setup:

```bash
bash mac/verify_setup.sh
```

## Terminal Multiplexers

- After a normal `prepare_new_box.sh` run, both `tmux` and `zellij` should be
  available on `PATH`.
- Both work fine with `zsh`. They are terminal multiplexers, not shells, so
  they run your shell inside panes and tabs rather than replacing zsh.
- `tmux` is the more portable choice for SSH, remote hosts, and shared team
  workflows.
- `zellij` has nicer built-in defaults and a more discoverable UI.
- Homebrew `screen` is also installed as a compatibility fallback, but `tmux`
  and `zellij` remain the preferred defaults.
- The Mac setup already seeds `~/.tmux.conf` copy-if-absent and auto-attaches
  `tmux` for SSH sessions in the managed shell fragment.

Quick start:

```bash
tmux
zellij
```

## C/C++ Toolchain

- A clean macOS install is not a reliable C/C++ build environment until Apple
  Command Line Tools are installed.
- `prepare_new_box.sh` makes Xcode Command Line Tools a hard prerequisite. If
  they are missing, it runs `xcode-select --install` and exits so you can
  finish the Apple installer, then re-run the bootstrap.
- After the bootstrap completes, you can compile C and C++ with Apple Clang,
  and the script also installs Homebrew `cmake`, `ninja`, and `pkg-config` for
  common native build workflows.
- Homebrew `gcc` is also installed as an extra compiler toolchain, but it is
  not made the default. Apple Clang remains the expected compiler for normal
  macOS and Xcode-oriented builds.
- The final `verify_setup.sh` pass now smoke-tests the toolchain by compiling
  and running a tiny C program and a tiny C++ program.

Basic examples:

```bash
clang hello.c -o hello
clang++ -std=c++17 hello.cpp -o hello
cmake -S . -B build
cmake --build build -j
```

If you need the full Apple SDKs for iOS or simulator builds, install full
Xcode from the App Store and run:

```bash
sudo xcodebuild -license accept
```

## Defaults And Flags

Most feature flags default to `1`. The main exceptions are:

- `NO_NET=0`
- `SKIP_BREW_UPDATE=0`
- `ENABLE_FIREWALL_STEALTH=0`
- `UPGRADE_NODE_GLOBALS=0`

Useful toggles:

- `INSTALL_GUI_APPS=0`: skip the GUI Brewfile (`iTerm2`, VS Code, Rectangle).
- `INSTALL_DOCKER=0`: skip Docker Desktop.
- `INSTALL_GITHUB_COPILOT_CLI=0`: skip the Copilot CLI cask.
- `INSTALL_CODEX_APP=0`: skip Codex.app.
- `INSTALL_CLAUDE_APP=0`: skip Claude.app.
- `INSTALL_CODEX=0`: skip the Codex CLI npm install.
- `INSTALL_CLAUDE_CODE=0`: skip the Claude Code npm install.
- `INSTALL_AI_ENV=0`: skip Python AI packages in Homebrew Python.
- `INSTALL_MINICONDA=0`: skip the default Miniconda install.
- `APPLY_MACOS_DEFAULTS=0`: skip `apply_defaults.sh`.
- `APPLY_DOTFILES=0`: skip `apply_dotfiles.sh`.
- `ENABLE_FIREWALL=0`: leave the macOS firewall unchanged.
- `ENABLE_FIREWALL_STEALTH=1`: also enable firewall stealth mode.
- `ENABLE_TOUCH_ID_FOR_SUDO=0`: leave sudo authentication unchanged.
- `SKIP_BREW_UPDATE=1`: use existing Homebrew metadata.
- `UPGRADE_NODE_GLOBALS=1`: upgrade Codex CLI / Claude Code instead of
  install-if-missing.

Developer extras, all default `1`:

- `INSTALL_EXTRA_CLIS=0`
  Skips the dormant extra CLI bundle (`tlrc`, `ncdu`, `meson`, `kubectl`,
  `rclone`, `ffmpeg`, archive helpers, and similar command-line tools).
- `INSTALL_LLAMA_CPP=0`
- `INSTALL_GO=0`
- `INSTALL_OLLAMA=0`
- `INSTALL_TAILSCALE=0`
- `INSTALL_RUST=0`
- `INSTALL_DEV_FONTS=0`
- `INSTALL_FIREFOX=0`
- `INSTALL_CHROME=0`
- `INSTALL_MLX=0`

Path override:

- `MINICONDA_DIR=/custom/path`: install Miniconda somewhere other than
  `~/miniconda3`.

## What The Scripts Manage

- `~/.config/pcprep/macos-shellenv.sh`
  This is sourced from `~/.zprofile` and `~/.bash_profile`. It sets up
  Homebrew, `~/.local/bin`, Cargo, and Miniconda helper functions.
- `~/.config/pcprep/pcprep-shell.bash`
  Managed bash fragment sourced from a fenced block in `~/.bashrc`.
- `~/.config/pcprep/pcprep-shell.zsh`
  Managed zsh fragment sourced from a fenced block in `~/.zshrc`.
- `~/.config/pcprep/pcprep-shell.common.sh`
  Shared bash/zsh environment and SSH/tmux helpers.
- `~/.config/pcprep/pcprep-aliases.sh`
  Managed copy of `ubuntu/.bash_aliases`, with Linux-only bits guarded so the
  same alias set can be sourced from macOS bash and zsh.
- Copy-if-absent shared files:
  - `~/.inputrc`
  - `~/.tmux.conf`
  - `~/.claude/settings.json`
  - `~/.codex/config.toml`
  - helper files from `ubuntu/` copied into `~/.local/bin`

## Important Behavior Notes

- Homebrew tools are installed alongside Apple’s built-ins. Nothing overwrites
  `/usr/bin` or `/bin`.
- Homebrew `gcc` is installed side-by-side for projects that specifically need
  GNU GCC, but the bootstrap does not export `CC`/`CXX` or otherwise switch the
  default compiler away from Apple Clang.
- Azure CLI (`az`) and AzCopy (`azcopy`) are part of the default core CLI set.
  The bootstrap also enables non-interactive Azure CLI extension installs and
  ensures the default macOS extension directory exists at
  `~/.azure/cliextensions`. Run `az login` when you want to authenticate the
  Azure CLI.
- `apply_dotfiles.sh` gives bash and zsh a shared alias/helper layer based on
  `ubuntu/.bash_aliases`. Linux-only entries are guarded in that file instead
  of being dropped, so Slurm / Kubernetes / remote-development aliases remain
  available on macOS.
- Login bash on macOS reads `~/.bash_profile`, not `~/.bashrc`, so the mac
  dotfile setup adds a small managed block to `~/.bash_profile` that sources
  `~/.bashrc`. New `bash` shells therefore pick up the same Homebrew shellenv,
  history settings, and shared aliases by default after the scripts run.
- The bootstrap front-loads sudo authentication and refreshes the cached sudo
  timestamp in the background during long runs, so password or Touch ID prompts
  should usually happen once per bootstrap rather than once per privileged step.
- GitHub CLI `gh` is part of `Brewfile.core`; there is no dedicated
  `INSTALL_GITHUB_CLI` flag.
- AI packages are installed into Homebrew `python@3.12`, not Apple’s Python.
- The default mac AI package set includes notebook/data-science basics
  (`rich`, `pytest`, `pandas`, `scikit-learn`, `matplotlib`, `jupyter`),
  TensorFlow / Keras, and the mainstream LLM tooling stack (`transformers`,
  `datasets`, `wandb`, `accelerate`, `einops`, `tokenizers`,
  `sentencepiece`, `lightning`, plus PyTorch and TensorBoard).
- Miniconda is installed by default into `~/miniconda3`, but it is left off
  `PATH` and `auto_activate_base` is disabled. Use `condaon` to activate conda
  base, `condaon ENV_NAME` for a named environment, and `condaoff` to fully
  deactivate it again.
- `INSTALL_EXTRA_CLIS=1` installs only CLI tools and one utility cask
  (`AppCleaner`). Nothing in that bundle adds login items or background daemons
  just by being installed.
- Ollama and Tailscale install the Homebrew formulas only, not the GUI casks,
  so they do not auto-start background daemons.
- Some post-install actions remain manual by design, such as app sign-in,
  Docker Desktop first launch, and `gh auth login`.

## Reversal

- Remove the `>>> pcprep macos zshrc >>>`, `>>> pcprep macos bashrc >>>`, and
  `>>> pcprep macos bash_profile >>>` blocks from `~/.zshrc`, `~/.bashrc`, and
  `~/.bash_profile` to stop loading the managed shell fragments.
- Delete `~/.config/pcprep/pcprep-shell.zsh`,
  `~/.config/pcprep/pcprep-shell.bash`,
  `~/.config/pcprep/pcprep-shell.common.sh`,
  `~/.config/pcprep/pcprep-aliases.sh`, and
  `~/.config/pcprep/macos-shellenv.sh` if you no longer want the managed files.
- Run `bash mac/revert_defaults.sh` to undo the macOS preference changes.
- Remove any copy-if-absent files from your home directory manually if you do
  not want them.

See `todo.md` for the candidate list behind the current defaults and
`unimplemented.md` for the items intentionally left out.
