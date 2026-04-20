#!/usr/bin/env bash
# Conservative bootstrap for a new macOS developer machine.
# Design goals:
# - Safe to re-run after partial setup or failure
# - Avoid invasive shell rewrites and highly personal tooling choices
# - Install the minimum trusted set that materially improves macOS for developers
# - Prepare a dependable Python and Node base for AI development workflows

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mac/common.sh
source "$SCRIPT_DIR/common.sh"

start_run_logging() {
  # Mirror the full run to a persistent logfile so failures can be reviewed
  # after the terminal scrollback is gone.  `prepare_new_box.latest.log` is a
  # stable symlink to the newest run for quick access.
  local log_dir
  local log_timestamp
  local latest_link

  if [ -n "${PCPREP_LOGGING_INITIALIZED:-}" ]; then
    return 0
  fi

  log_dir="${PCPREP_LOG_DIR:-$HOME/Library/Logs/pcprep}"
  log_timestamp="$(date '+%Y%m%d-%H%M%S')"
  PCPREP_LOG_FILE="${PCPREP_LOG_FILE:-$log_dir/prepare_new_box.${log_timestamp}.log}"
  ensure_dir "$(dirname "$PCPREP_LOG_FILE")"
  latest_link="$(dirname "$PCPREP_LOG_FILE")/prepare_new_box.latest.log"

  exec > >(/usr/bin/tee -a "$PCPREP_LOG_FILE") 2>&1
  ln -sfn "$(basename "$PCPREP_LOG_FILE")" "$latest_link" 2>/dev/null || true

  export PCPREP_LOG_FILE
  PCPREP_LOGGING_INITIALIZED=1
  export PCPREP_LOGGING_INITIALIZED

  log "Run log: $PCPREP_LOG_FILE"
  log "Latest-log symlink: $latest_link"
}

# Install the ERR trap *after* sourcing common.sh so on_err is always defined
# at the moment the trap fires (including when the source itself errors out).
start_run_logging
trap 'on_err "${BASH_COMMAND}" "${LINENO}" "$?"' ERR
trap 'stop_sudo_keepalive' EXIT

NO_NET="${NO_NET:-0}"
SKIP_BREW_UPDATE="${SKIP_BREW_UPDATE:-0}"
INSTALL_GUI_APPS="${INSTALL_GUI_APPS:-1}"
INSTALL_DOCKER="${INSTALL_DOCKER:-1}"
INSTALL_GITHUB_COPILOT_CLI="${INSTALL_GITHUB_COPILOT_CLI:-1}"
INSTALL_CODEX_APP="${INSTALL_CODEX_APP:-1}"
INSTALL_CLAUDE_APP="${INSTALL_CLAUDE_APP:-1}"
INSTALL_CODEX="${INSTALL_CODEX:-1}"
INSTALL_CLAUDE_CODE="${INSTALL_CLAUDE_CODE:-1}"
INSTALL_AI_ENV="${INSTALL_AI_ENV:-1}"
# Dormant-by-default Conda bootstrap.  We install Miniconda by default so the
# bits are already present if the user later needs conda, but we keep it off
# PATH and out of auto-activation so Homebrew Python + uv remain the baseline.
INSTALL_MINICONDA="${INSTALL_MINICONDA:-1}"
MINICONDA_DIR="${MINICONDA_DIR:-$HOME/miniconda3}"
APPLY_MACOS_DEFAULTS="${APPLY_MACOS_DEFAULTS:-1}"
# APPLY_DOTFILES runs mac/apply_dotfiles.sh after the `defaults write` pass.
# Installs a managed zsh fragment with history/AI-cache/aliases and copies
# shared ~/.tmux.conf, ~/.claude/settings.json, ~/.codex/config.toml from
# ubuntu/ (copy-if-absent, so existing user edits are preserved).
APPLY_DOTFILES="${APPLY_DOTFILES:-1}"
ENABLE_FIREWALL="${ENABLE_FIREWALL:-1}"
ENABLE_FIREWALL_STEALTH="${ENABLE_FIREWALL_STEALTH:-0}"
ENABLE_TOUCH_ID_FOR_SUDO="${ENABLE_TOUCH_ID_FOR_SUDO:-1}"
CONFIGURE_SUDO_TIMESTAMP_TIMEOUT="${CONFIGURE_SUDO_TIMESTAMP_TIMEOUT:-1}"
SUDO_TIMESTAMP_TIMEOUT_MINUTES="${SUDO_TIMESTAMP_TIMEOUT_MINUTES:-30}"
UPGRADE_NODE_GLOBALS="${UPGRADE_NODE_GLOBALS:-0}"
# Keep the stock managed prompt simple by default, but allow an explicit
# Powerlevel10k opt-in for users who want a richer zsh prompt.
USE_POWERLEVEL10K_PROMPT="${USE_POWERLEVEL10K_PROMPT:-0}"

# Additional installs — all default ON so a fresh MacBook gets the popular-dev
# loadout automatically.  Set any individual flag to 0 to opt out of that item.
# Several of these touch background processes; each maybe_* function explains
# the tradeoff inline and emits append_next_step notes so nothing surprises
# a user doing light non-development work.
INSTALL_OLLAMA="${INSTALL_OLLAMA:-1}"
INSTALL_DEV_FONTS="${INSTALL_DEV_FONTS:-1}"
INSTALL_RUST="${INSTALL_RUST:-1}"
INSTALL_GO="${INSTALL_GO:-1}"
INSTALL_TAILSCALE="${INSTALL_TAILSCALE:-1}"
INSTALL_MLX="${INSTALL_MLX:-1}"
INSTALL_LLAMA_CPP="${INSTALL_LLAMA_CPP:-1}"
INSTALL_EXTRA_CLIS="${INSTALL_EXTRA_CLIS:-1}"
INSTALL_FIREFOX="${INSTALL_FIREFOX:-1}"
INSTALL_CHROME="${INSTALL_CHROME:-1}"

user_name="${user_name:-}"
user_email="${user_email:-}"

# NEXT_STEPS is already initialized by common.sh; we only declare HAVE_SUDO here.
HAVE_SUDO=0

ensure_existing_ssh_setup() {
  if [ ! -d "$HOME/.ssh" ]; then
    die "~/.ssh was not found. Create $HOME/.ssh with your SSH keys and config first, then re-run this script."
  fi
}

apply_shared_ssh_permissions() {
  local ssh_perms_script

  ssh_perms_script="$SCRIPT_DIR/../ubuntu/ssh_perms.sh"
  if [ ! -f "$ssh_perms_script" ]; then
    die "Missing shared SSH permissions helper: $ssh_perms_script"
  fi

  log "Applying SSH permissions from ubuntu/ssh_perms.sh."
  bash "$ssh_perms_script"
}

collect_preflight_inputs() {
  # Front-load every stdin-driven prompt so the rest of the bootstrap can run
  # unattended once package installs and config steps begin. We only prompt
  # for Git identity when it is truly missing from the existing global config.
  # That keeps reruns quiet on already-configured machines and avoids asking
  # again after a partially successful earlier bootstrap.
  local entered
  local existing_name
  local existing_email

  existing_name="$(git_global_config_get "user.name")"
  existing_email="$(git_global_config_get "user.email")"

  if [ -n "$existing_name" ]; then
    user_name="$existing_name"
  elif is_interactive && [ -z "$user_name" ]; then
    printf 'Git user.name (leave blank to skip): '
    read -r entered
    if [ -n "$entered" ]; then
      user_name="$entered"
    fi
  fi

  if [ -n "$existing_email" ]; then
    user_email="$existing_email"
  elif is_interactive && [ -z "$user_email" ]; then
    printf 'Git user.email (leave blank to skip): '
    read -r entered
    if [ -n "$entered" ]; then
      user_email="$entered"
    fi
  fi
}

persist_preflight_git_identity() {
  # Persist any just-entered Git identity immediately instead of waiting until
  # the later configure_git pass. That way a brew failure or other mid-run
  # error does not force the user to re-enter the same values on the rerun.
  if ! command_exists git; then
    if [ -n "$user_name" ] || [ -n "$user_email" ]; then
      warn "Git is not available yet. Deferring Git identity writes until the later Git configuration step."
    fi
    return 0
  fi

  _ensure_git_identity_key "user.name"  "name"  "$user_name"
  _ensure_git_identity_key "user.email" "email" "$user_email"
}

ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1 && xcrun --find clang >/dev/null 2>&1; then
    log "Xcode Command Line Tools are already installed."
    return 0
  fi

  if bool_is_true "$NO_NET"; then
    die "Xcode Command Line Tools are required for Homebrew and package builds, but NO_NET=1 prevents installing them."
  fi

  log "Requesting Xcode Command Line Tools installation from Apple."
  xcode-select --install >/dev/null 2>&1 || true
  die "Finish the Xcode Command Line Tools install in the macOS dialog, then re-run this script."
}

ensure_homebrew() {
  # Install Homebrew if absent, repair PATH if present-but-unconfigured, and
  # persist the managed shellenv so cargo/brew land on PATH in future shells
  # without editing the user's own .zshrc / .bash_profile.
  local preferred_prefix
  local brew_bin
  local brew_shellenv_file
  local shellenv_block
  local shellenv_source_line
  local main_venv_dir

  preferred_prefix="$(brew_prefix_guess)"
  brew_bin="$preferred_prefix/bin/brew"
  main_venv_dir="$(default_main_venv_dir)"

  if command_exists brew; then
    brew_bin="$(command -v brew)"
    log "Homebrew is already installed."
  elif [ -x "$brew_bin" ]; then
    log "Homebrew exists at $brew_bin but is not yet on PATH. Repairing shell configuration."
  else
    if bool_is_true "$NO_NET"; then
      die "Homebrew is not installed and NO_NET=1 prevents installing it."
    fi

    log "Installing Homebrew from the official installer."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  if [ ! -x "$brew_bin" ]; then
    die "Homebrew was expected at $brew_bin, but no executable brew binary was found."
  fi

  # Evaluate brew shellenv in the current shell so subsequent commands use the
  # correct Homebrew prefix immediately, even before a new terminal is opened.
  eval "$("$brew_bin" shellenv)"

  brew_shellenv_file="$HOME/.config/pcprep/macos-shellenv.sh"
  shellenv_block="# Managed by pcprep. Source Homebrew and the user-local bin directory.
if [ -n \"\${PCPREP_MACOS_SHELLENV_LOADED:-}\" ]; then
  return 0 2>/dev/null || true
fi
PCPREP_MACOS_SHELLENV_LOADED=1

export USE_POWERLEVEL10K_PROMPT=\"${USE_POWERLEVEL10K_PROMPT:-0}\"
export MAIN_VENV_DIR=\"$main_venv_dir\"
export AI_VENV_DIR=\"$main_venv_dir\"
export AUTO_ACTIVATE_MAIN=\"${AUTO_ACTIVATE_MAIN:-1}\"

if [ -x \"$brew_bin\" ]; then
  eval \"\$($brew_bin shellenv)\"
fi

export PATH=\"\$HOME/.local/bin:\$PATH\"

# Rust toolchain: picked up automatically when pcprep's maybe_install_rust
# has populated ~/.cargo/bin.  Keeping the check here avoids editing the
# user's ~/.zshrc / ~/.bash_profile to add cargo manually.
if [ -d \"\$HOME/.cargo/bin\" ]; then
  export PATH=\"\$HOME/.cargo/bin:\$PATH\"
fi

# Managed main Python environment.  It stays isolated from Homebrew's base
# interpreter, but interactive shells can auto-activate it so it behaves like
# the default day-to-day Python.  'mainoff' returns to the plain Homebrew
# environment, 'condaon' deactivates it before entering Miniconda, and Apple's
# Python remains available explicitly via '/usr/bin/python3' or 'applepy'.
_pcprep_deactivate_current_venv() {
  if [ -n \"\${VIRTUAL_ENV:-}\" ] && command -v deactivate >/dev/null 2>&1; then
    deactivate >/dev/null 2>&1 || true
  fi
}

applepy() {
  /usr/bin/python3 \"\$@\"
}

if [ -f \"$main_venv_dir/bin/activate\" ]; then
  mainon() {
    if [ \"\${VIRTUAL_ENV:-}\" != \"$main_venv_dir\" ]; then
      _pcprep_deactivate_current_venv
    fi
    if [ \"\${CONDA_SHLVL:-0}\" -gt 0 ] && [ -f \"$MINICONDA_DIR/etc/profile.d/conda.sh\" ]; then
      . \"$MINICONDA_DIR/etc/profile.d/conda.sh\"
      while [ \"\${CONDA_SHLVL:-0}\" -gt 0 ]; do
        conda deactivate >/dev/null 2>&1 || break
      done
    fi
    . \"$main_venv_dir/bin/activate\"
  }

  mainoff() {
    if [ \"\${VIRTUAL_ENV:-}\" = \"$main_venv_dir\" ]; then
      _pcprep_deactivate_current_venv
    fi
  }
fi

# Optional Miniconda helpers.  We deliberately do NOT add Miniconda to PATH
# by default, so Homebrew Python + uv stay the default toolchain for every new
# shell.  Use condaon to activate base (or a named env), and condaoff to
# fully deactivate conda again when you want the shell back on the Homebrew /
# system path.
if [ -f \"$MINICONDA_DIR/etc/profile.d/conda.sh\" ]; then
  condaon() {
    if [ \"\${VIRTUAL_ENV:-}\" = \"$main_venv_dir\" ]; then
      mainoff
    else
      _pcprep_deactivate_current_venv
    fi
    . \"$MINICONDA_DIR/etc/profile.d/conda.sh\"
    if [ \"\$#\" -gt 0 ]; then
      conda activate \"\$1\"
    else
      conda activate base
    fi
  }

  condaoff() {
    if command -v conda >/dev/null 2>&1; then
      while [ \"${CONDA_SHLVL:-0}\" -gt 0 ]; do
        conda deactivate >/dev/null 2>&1 || break
      done
    fi
  }
fi"
  upsert_managed_block \
    "$brew_shellenv_file" \
    "# >>> pcprep macos shellenv >>>" \
    "# <<< pcprep macos shellenv <<<" \
    "$shellenv_block"

  # Keep the shellenv sourcing itself managed and reversible too.  We also
  # remove the older unmanaged one-line injection if it exists from a previous
  # pcprep run so reruns converge on fenced blocks.
  shellenv_source_line='[ -f "$HOME/.config/pcprep/macos-shellenv.sh" ] && source "$HOME/.config/pcprep/macos-shellenv.sh"'
  remove_exact_line_from_file "$HOME/.zprofile" "$shellenv_source_line"
  remove_exact_line_from_file "$HOME/.bash_profile" "$shellenv_source_line"
  upsert_managed_block \
    "$HOME/.zprofile" \
    "# >>> pcprep macos zprofile shellenv >>>" \
    "# <<< pcprep macos zprofile shellenv <<<" \
    "$shellenv_source_line"
  upsert_managed_block \
    "$HOME/.bash_profile" \
    "# >>> pcprep macos bash_profile shellenv >>>" \
    "# <<< pcprep macos bash_profile shellenv <<<" \
    "$shellenv_source_line"
  ensure_dir "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
}

install_brew_bundle_file() {
  local bundle_file="$1"
  local label="$2"

  if [ ! -f "$bundle_file" ]; then
    die "Missing bundle file: $bundle_file"
  fi

  log "Installing $label from $(basename "$bundle_file")."
  # --no-upgrade keeps reruns idempotent by leaving already-installed formulas alone.
  # (The older --no-lock flag was removed in Homebrew 4.2+ and would now error out.)
  brew bundle --file="$bundle_file" --no-upgrade
}

install_core_gui_apps() {
  # Install the small curated GUI set one cask at a time so we can adopt an
  # already-present app bundle instead of failing when the user installed that
  # app manually before running pcprep.
  log "Installing core GUI applications."
  brew_install_cask_app_if_missing \
    iterm2 \
    "iTerm2" \
    "/Applications/iTerm.app" \
    "$HOME/Applications/iTerm.app"
  brew_install_cask_app_if_missing \
    visual-studio-code \
    "Visual Studio Code" \
    "/Applications/Visual Studio Code.app" \
    "$HOME/Applications/Visual Studio Code.app"
  brew_install_cask_app_if_missing \
    rectangle \
    "Rectangle" \
    "/Applications/Rectangle.app" \
    "$HOME/Applications/Rectangle.app"
}

maybe_update_brew() {
  if bool_is_true "$NO_NET"; then
    warn "NO_NET=1 is set. Skipping 'brew update'."
    return 0
  fi

  if bool_is_true "$SKIP_BREW_UPDATE"; then
    warn "SKIP_BREW_UPDATE=1 is set. Using existing Homebrew metadata."
    return 0
  fi

  log "Refreshing Homebrew package metadata."
  brew update
}

maybe_install_docker() {
  if ! bool_is_true "$INSTALL_DOCKER"; then
    warn "INSTALL_DOCKER=0 set. Skipping Docker Desktop."
    return 0
  fi

  brew_install_cask_app_if_missing \
    docker \
    "Docker Desktop" \
    "/Applications/Docker.app" \
    "$HOME/Applications/Docker.app"

  append_next_step "Launch Docker Desktop once so macOS grants permissions and the Docker daemon can finish initialization."
  # Docker Desktop's Linux VM idles at roughly 1-3W continuously once started, which
  # can cost 1-3 hours of MacBook battery life per day even with no containers running.
  # Surface this so users doing light non-development work can keep it off at login.
  append_next_step "In Docker Desktop → Settings → General, disable 'Start Docker Desktop when you log in' unless you actually need containers running all day. The VM draws noticeable battery even when idle."
  append_next_step "Quit Docker Desktop from the menu bar when you're not actively using it to preserve battery on light-use days."
}

brew_install_if_missing() {
  # Idempotent brew install helper.  Checks whether the named formula or cask
  # is already installed so reruns do not reinstall or upgrade unnecessarily.
  #   $1: "formula" or "cask"
  #   $2: package name (e.g. "bash", "firefox")
  #   $3: human-readable label for log output (optional, defaults to $2)
  local kind="$1"
  local name="$2"
  local label="${3:-$name}"

  if brew list "--$kind" "$name" >/dev/null 2>&1; then
    log "$label is already installed."
    return 0
  fi

  log "Installing $label."
  if [ "$kind" = "cask" ]; then
    brew install --cask "$name"
  else
    brew install "$name"
  fi
}

brew_install_cask_app_if_missing() {
  # Homebrew casks fail when the target .app bundle already exists but is not
  # Homebrew-managed. Prefer adopting that existing app into Homebrew cask
  # management over overwriting it or erroring out mid-bootstrap.
  #   $1: cask name
  #   $2: human-readable label
  #   $3+: candidate app bundle paths to adopt if already present
  local name="$1"
  local label="$2"
  local app_path
  local app_dir

  shift 2

  if brew list --cask "$name" >/dev/null 2>&1; then
    log "$label is already installed."
    return 0
  fi

  for app_path in "$@"; do
    if [ -d "$app_path" ]; then
      app_dir="$(dirname "$app_path")"
      log "$label already exists at $app_path. Adopting it into Homebrew Cask management."
      if brew install --cask --adopt --appdir="$app_dir" "$name"; then
        return 0
      fi
      warn "Homebrew could not adopt the existing $label app bundle at $app_path. Leaving the existing app in place and continuing."
      return 0
    fi
  done

  log "Installing $label."
  brew install --cask "$name"
}

maybe_install_extra_clis() {
  # Expanded bundle of quality-of-life, build, networking, and archive CLIs
  # mapped from ubuntu/extra_install.sh where the tools are available on macOS
  # and remain fully dormant unless the user invokes them.
  if ! bool_is_true "$INSTALL_EXTRA_CLIS"; then
    warn "INSTALL_EXTRA_CLIS=0 set. Skipping extra CLI bundle."
    return 0
  fi

  # TLDR client: Homebrew's old `tldr` formula is currently disabled, so use
  # the officially recommended replacement instead.
  brew_install_if_missing formula tlrc "tlrc"
  # TUI disk usage explorer; complements 'du' and 'btop' for storage triage.
  brew_install_if_missing formula ncdu "ncdu"
  # moreutils conflicts with GNU parallel in Homebrew; prefer moreutils on macOS
  # because `sponge`, `ts`, and `vidir` are broadly useful day-to-day helpers.
  brew_install_if_missing formula moreutils "moreutils"
  brew_install_if_missing formula rename "rename"
  brew_install_if_missing formula entr "entr"
  brew_install_if_missing formula rsync "rsync"
  # CPU/memory/IO benchmark for quick machine sanity checks.
  brew_install_if_missing formula sysbench "sysbench"
  # Host-to-host network throughput testing for distributed workloads.
  brew_install_if_missing formula iperf3 "iperf3"
  brew_install_if_missing formula meson "Meson"
  brew_install_if_missing formula autoconf "autoconf"
  brew_install_if_missing formula automake "automake"
  brew_install_if_missing formula libtool "GNU libtool"
  brew_install_if_missing formula ccache "ccache"
  brew_install_if_missing formula autossh "autossh"
  brew_install_if_missing formula mtr "mtr"
  brew_install_if_missing formula nmap "nmap"
  brew_install_if_missing formula kubernetes-cli "kubectl"
  brew_install_if_missing formula rclone "rclone"
  brew_install_if_missing formula zstd "zstd"
  brew_install_if_missing formula pigz "pigz"
  brew_install_if_missing formula pbzip2 "pbzip2"
  brew_install_if_missing formula sevenzip "7-Zip"
  brew_install_if_missing formula unar "unar"
  brew_install_if_missing formula ffmpeg "FFmpeg"
  # GUI-driven app uninstaller.  Its optional "SmartDelete" helper is dormant
  # until enabled in-app, so installing the cask costs effectively nothing.
  brew_install_cask_app_if_missing \
    appcleaner \
    "AppCleaner" \
    "/Applications/AppCleaner.app" \
    "$HOME/Applications/AppCleaner.app"
}

maybe_install_llama_cpp() {
  # Pure CLI inference engine for local LLMs.  No launchd agent, no background
  # work — the tools only run when invoked directly.
  if ! bool_is_true "$INSTALL_LLAMA_CPP"; then
    warn "INSTALL_LLAMA_CPP=0 set. Skipping llama.cpp."
    return 0
  fi
  brew_install_if_missing formula "llama.cpp" "llama.cpp"
}

maybe_install_go() {
  # Go toolchain via Homebrew.  Go binaries land under $(brew --prefix)/bin,
  # which is already on PATH via the managed shellenv block.
  if ! bool_is_true "$INSTALL_GO"; then
    warn "INSTALL_GO=0 set. Skipping Go toolchain."
    return 0
  fi
  brew_install_if_missing formula go "Go toolchain"
}

miniconda_installer_url() {
  # Use Anaconda's architecture-specific "latest" installer so the bootstrap
  # does not need hand-maintained point-release URLs.
  case "$(uname -m)" in
    arm64)
      printf '%s\n' "https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh"
      ;;
    x86_64)
      printf '%s\n' "https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"
      ;;
    *)
      die "Unsupported macOS CPU architecture for Miniconda install: $(uname -m)"
      ;;
  esac
}

maybe_install_miniconda() {
  # Install Miniconda into ~/miniconda3 (or MINICONDA_DIR) without running
  # `conda init` and without prepending it to PATH.  That keeps uv, Homebrew
  # Python, and Apple's system Python behavior unchanged until the user
  # explicitly activates a conda shell with `condaon`.
  local installer_url
  local installer_path

  if ! bool_is_true "$INSTALL_MINICONDA"; then
    warn "INSTALL_MINICONDA=0 set. Skipping Miniconda."
    return 0
  fi

  if [ -e "$MINICONDA_DIR" ] && [ ! -x "$MINICONDA_DIR/bin/conda" ]; then
    die "MINICONDA_DIR exists but does not look like a Miniconda install: $MINICONDA_DIR"
  fi

  if [ -x "$MINICONDA_DIR/bin/conda" ]; then
    log "Miniconda is already installed at $MINICONDA_DIR."
  else
    if bool_is_true "$NO_NET"; then
      warn "NO_NET=1 is set and Miniconda is not already installed at $MINICONDA_DIR. Skipping Miniconda."
      return 0
    fi
    if ! command_exists curl; then
      die "curl is required to download the Miniconda installer."
    fi

    installer_url="$(miniconda_installer_url)"
    installer_path="$(mktemp "${TMPDIR:-/tmp}/miniconda-installer.XXXXXX.sh")"

    log "Installing Miniconda at $MINICONDA_DIR without shell init or PATH takeover."
    curl -fsSL "$installer_url" -o "$installer_path"
    bash "$installer_path" -b -u -p "$MINICONDA_DIR"
    rm -f "$installer_path"
  fi

  # Keep base dormant unless the user explicitly opts in for a given shell.
  "$MINICONDA_DIR/bin/conda" config --system --set auto_activate_base false >/dev/null

  append_next_step "Miniconda is installed at $MINICONDA_DIR but intentionally left off PATH so Homebrew Python + uv remain the default toolchain."
  append_next_step "Open a new shell and run 'condaon' to activate conda base, or 'condaon ENV_NAME' to activate a specific environment. Run 'condaoff' to fully deactivate conda again."
  append_next_step "Miniconda installs by default now. If you want to skip it on a future run, set INSTALL_MINICONDA=0."
}

maybe_install_ollama() {
  # Install Ollama's FORMULA (CLI binary), NOT the cask (GUI app).  The cask
  # ships a login item that starts the Ollama server every time the user logs
  # in, which costs battery even when no model is loaded.  The formula installs
  # just the binaries; the server only runs when the user invokes
  # `ollama serve` explicitly, which matches the "no unexpected background
  # daemons" goal for this bootstrap.
  if ! bool_is_true "$INSTALL_OLLAMA"; then
    warn "INSTALL_OLLAMA=0 set. Skipping Ollama."
    return 0
  fi
  brew_install_if_missing formula ollama "Ollama CLI"
  append_next_step "Ollama is installed as a CLI with no auto-start daemon. Run 'ollama serve' in a terminal only when you actually need local-model inference. Avoid 'brew services start ollama' unless you want the server running at every login — the persistent process is a real battery cost on light-use days."
}

maybe_install_tailscale() {
  # Install Tailscale's FORMULA (CLI + tailscaled binary), NOT the cask.  The
  # cask installs a System Extension and a background network daemon that
  # auto-starts after the user approves it once; the formula leaves daemon
  # lifecycle management in the user's hands so the ~0.1-0.5W idle cost is
  # only paid when VPN access is actually in use.
  if ! bool_is_true "$INSTALL_TAILSCALE"; then
    warn "INSTALL_TAILSCALE=0 set. Skipping Tailscale."
    return 0
  fi
  brew_install_if_missing formula tailscale "Tailscale CLI"
  append_next_step "Tailscale is installed as a CLI with no auto-start daemon. Start it manually with 'sudo brew services start tailscale' when you need mesh-VPN access, and 'sudo brew services stop tailscale' afterwards to preserve battery."
}

maybe_install_rust() {
  # Install the stable Rust toolchain through rustup.  The rustup-init bootstrap
  # binary itself is fetched via Homebrew so we avoid piping a remote shell
  # script through sudo.  --no-modify-path keeps rustup out of the user's
  # ~/.zshrc / ~/.bash_profile; pcprep's managed shellenv block already adds
  # ~/.cargo/bin to PATH conditionally (see ensure_homebrew above).
  if ! bool_is_true "$INSTALL_RUST"; then
    warn "INSTALL_RUST=0 set. Skipping Rust toolchain."
    return 0
  fi

  if [ -x "$HOME/.cargo/bin/rustup" ]; then
    log "rustup is already installed."
    return 0
  fi

  brew_install_if_missing formula rustup-init "rustup installer"

  log "Running rustup-init to install the stable Rust toolchain."
  rustup-init -y --default-toolchain stable --no-modify-path

  append_next_step "Rust toolchain installed at ~/.cargo/bin. Restart your terminal (or 'source ~/.config/pcprep/macos-shellenv.sh') so 'cargo' and 'rustc' land on PATH."
}

maybe_install_dev_fonts() {
  # Developer monospaced fonts with programming ligatures and nerd-font glyphs.
  # Homebrew folded the cask-fonts tap into the main cask repository in 2023,
  # so no extra tap is required.  Font installs are fully reversible via
  # `brew uninstall --cask <font-name>`.
  if ! bool_is_true "$INSTALL_DEV_FONTS"; then
    warn "INSTALL_DEV_FONTS=0 set. Skipping developer fonts."
    return 0
  fi
  brew_install_if_missing cask font-jetbrains-mono "JetBrains Mono"
  brew_install_if_missing cask font-meslo-lg-nerd-font "MesloLG Nerd Font"
  brew_install_if_missing cask font-fira-code "Fira Code"
  append_next_step "Set your Terminal, iTerm2, or editor font to JetBrains Mono, MesloLGS Nerd Font, or Fira Code if you want to use the installed developer fonts."
}

maybe_install_powerlevel10k() {
  # Optional zsh theme for users who want a richer prompt than the plain
  # built-in `%2~ %#` default.  Kept explicit so prompt theming stays a choice,
  # not an accidental side effect of the base bootstrap.
  if ! bool_is_true "$USE_POWERLEVEL10K_PROMPT"; then
    return 0
  fi

  brew_install_if_missing formula powerlevel10k "Powerlevel10k"
  append_next_step "Powerlevel10k prompt is enabled for new zsh shells. If the glyphs look wrong, set your Terminal or iTerm2 font to MesloLGS Nerd Font."
}

maybe_install_firefox() {
  # Firefox cask.  Mozilla Maintenance Service is dormant unless Firefox is
  # running, so installing the cask has no idle cost.
  if ! bool_is_true "$INSTALL_FIREFOX"; then
    warn "INSTALL_FIREFOX=0 set. Skipping Firefox."
    return 0
  fi
  brew_install_cask_app_if_missing \
    firefox \
    "Firefox" \
    "/Applications/Firefox.app" \
    "$HOME/Applications/Firefox.app"
}

maybe_install_chrome() {
  # Google Chrome cask.  Chrome ships Google Software Update (Keystone), a
  # launchd agent that periodically polls for updates even when Chrome itself
  # is quit.  Surface this through append_next_step so users who only need
  # Chrome occasionally can disable the updater if they prefer.
  if ! bool_is_true "$INSTALL_CHROME"; then
    warn "INSTALL_CHROME=0 set. Skipping Google Chrome."
    return 0
  fi
  brew_install_cask_app_if_missing \
    google-chrome \
    "Google Chrome" \
    "/Applications/Google Chrome.app" \
    "$HOME/Applications/Google Chrome.app"
  append_next_step "Chrome installs Google's Keystone auto-updater as a persistent launchd agent that runs even when Chrome is quit. If you rarely use Chrome, you can set 'defaults write com.google.Keystone.Agent checkInterval 0' to pause its polling."
}

maybe_install_github_copilot_cli() {
  # GitHub Copilot CLI ships as a Homebrew cask.  Keeping it explicit here
  # makes the bootstrap intent obvious and keeps authentication guidance next
  # to the install step instead of buried in generic Brewfile comments.
  if ! bool_is_true "$INSTALL_GITHUB_COPILOT_CLI"; then
    warn "INSTALL_GITHUB_COPILOT_CLI=0 set. Skipping GitHub Copilot CLI."
    return 0
  fi

  brew_install_if_missing cask copilot-cli "GitHub Copilot CLI"
  append_next_step "Run 'copilot' and use '/login' to authenticate GitHub Copilot CLI with your Copilot-enabled GitHub account."
}

maybe_install_ai_apps() {
  # Install the desktop apps explicitly so they are easy to opt out of without
  # tying them to the generic GUI app bundle.
  if bool_is_true "$INSTALL_CODEX_APP"; then
    brew_install_cask_app_if_missing \
      codex-app \
      "Codex app" \
      "/Applications/Codex.app" \
      "$HOME/Applications/Codex.app"
    append_next_step "Launch Codex.app and sign in with your ChatGPT account to finish setup."
  else
    warn "INSTALL_CODEX_APP=0 set. Skipping Codex app."
  fi

  if bool_is_true "$INSTALL_CLAUDE_APP"; then
    brew_install_cask_app_if_missing \
      claude \
      "Claude app" \
      "/Applications/Claude.app" \
      "$HOME/Applications/Claude.app"
    append_next_step "Launch Claude.app and sign in with your Anthropic account to finish setup."
  else
    warn "INSTALL_CLAUDE_APP=0 set. Skipping Claude app."
  fi
}

maybe_link_vscode_cli() {
  local vscode_cli
  local user_link

  if command_exists code; then
    return 0
  fi

  vscode_cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  user_link="$HOME/.local/bin/code"

  if [ ! -x "$vscode_cli" ]; then
    vscode_cli="$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  fi

  if [ -x "$vscode_cli" ]; then
    log "Creating a stable user-local 'code' symlink for VS Code."
    ln -sf "$vscode_cli" "$user_link"
  fi
}

configure_azure_cli() {
  # Azure CLI extensions on macOS install into the user's Azure config tree by
  # default (`~/.azure/cliextensions`), so the macOS equivalent of the Linux
  # `/opt/az/extensions` workaround is to ensure the user-scoped directory
  # exists and is writable, then enable dynamic install with no prompt.
  local azure_config_dir
  local azure_extension_dir

  if ! command_exists az; then
    warn "Azure CLI is not available yet. Skipping Azure CLI configuration."
    return 0
  fi

  azure_config_dir="${AZURE_CONFIG_DIR:-$HOME/.azure}"
  azure_extension_dir="${AZURE_EXTENSION_DIR:-$azure_config_dir/cliextensions}"

  ensure_dir "$azure_config_dir"
  ensure_dir "$azure_extension_dir"

  # Keep the Azure CLI config tree user-owned and writable without the
  # over-broad world-writable permissions used by some Linux package layouts.
  chmod 700 "$azure_config_dir" "$azure_extension_dir"

  log "Configuring Azure CLI for non-interactive extension installs."
  az config set extension.use_dynamic_install=yes_without_prompt >/dev/null
}

_ensure_git_identity_key() {
  # Set a git identity key (user.name / user.email) only when it is not
  # already configured.  Prefers a preloaded env / preflight value and
  # silently skips when none is available.  Keeps configure_git symmetric for
  # name and email instead of duplicating 10 lines of branching twice.
  #   $1: git config key  (e.g. "user.name")
  #   $2: human-readable label for log output    (e.g. "name")
  #   $3: preloaded value from the environment   (may be empty)
  local key="$1"
  local label="$2"
  local preloaded="$3"
  local existing

  existing="$(git config --global --get "$key" || true)"
  if [ -n "$existing" ]; then
    return 0
  fi

  if [ -n "$preloaded" ]; then
    log "Setting global Git $label."
    git config --global "$key" "$preloaded"
  fi
}

configure_git() {
  # Apply conservative global git defaults that work across editors and hosts.
  # All writes target the global scope; repo-local configs remain untouched.
  local gitignore_file

  if ! command_exists git; then
    warn "Git is not available yet. Skipping Git configuration."
    return 0
  fi

  log "Applying conservative global Git defaults."
  # Modern default branch name; matches GitHub / GitLab conventions.
  git config --global init.defaultBranch main
  # Rebase-on-pull keeps histories linear and avoids accidental merge commits.
  git config --global pull.rebase true
  # Clean up deleted upstream branches automatically on every fetch.
  git config --global fetch.prune true
  # Move-detection colors for word-swapped diffs make refactor reviews easier.
  git config --global diff.colorMoved zebra
  # Store HTTPS credentials in the macOS Keychain instead of plain text.
  git config --global credential.helper osxkeychain
  # Prefer SSH for GitHub-hosted repos so copy-pasted HTTPS clone URLs still
  # use the user's SSH keys instead of falling back to password/token prompts.
  git config --global 'url.ssh://git@github.com/.insteadOf' https://github.com/
  git config --global 'url.ssh://git@gist.github.com/.insteadOf' https://gist.github.com/
  # Treat the working tree as LF; convert CRLF inputs to LF on add but never
  # rewrite LF to CRLF (safe default when collaborating with Windows peers).
  git config --global core.eol lf
  git config --global core.autocrlf input

  if command_exists code; then
    # Use VS Code as the default editor when it's available (so `git commit`
    # with no -m opens a familiar editor instead of vi).
    git config --global core.editor "code --wait"
  fi

  # Global gitignore: keep macOS / trash-bin droppings out of every repo.
  gitignore_file="$HOME/.gitignore_global"
  ensure_line_in_file "$gitignore_file" ".DS_Store"
  ensure_line_in_file "$gitignore_file" ".Trash-*"
  git config --global core.excludesfile "$gitignore_file"

  if command_exists git-lfs; then
    # Writes the global git-lfs filters once; --skip-repo keeps it from
    # trying to initialize LFS in a repo we are not actually inside.
    git lfs install --skip-repo >/dev/null
  fi

  _ensure_git_identity_key "user.name"  "name"  "$user_name"
  _ensure_git_identity_key "user.email" "email" "$user_email"
}

npm_global_is_installed() {
  local package_name="$1"
  npm list -g --depth=0 "$package_name" >/dev/null 2>&1
}

install_npm_global() {
  local package_name="$1"
  local binary_name="$2"
  local human_name="$3"

  if ! command_exists npm; then
    warn "npm is not available. Skipping $human_name."
    return 0
  fi

  if bool_is_true "$UPGRADE_NODE_GLOBALS"; then
    log "Installing or upgrading $human_name."
    npm install -g "${package_name}@latest"
  elif npm_global_is_installed "$package_name"; then
    log "$human_name is already installed."
  else
    log "Installing $human_name."
    npm install -g "$package_name"
  fi

  if ! command_exists "$binary_name"; then
    warn "$human_name was installed, but '$binary_name' is not on PATH yet. Open a new shell if needed."
  fi
}

maybe_install_ai_clis() {
  if bool_is_true "$NO_NET"; then
    warn "NO_NET=1 is set. Skipping Codex and Claude Code installation."
    return 0
  fi

  if bool_is_true "$INSTALL_CODEX"; then
    install_npm_global "@openai/codex" "codex" "Codex CLI"
    append_next_step "Run 'codex' once and sign in with your ChatGPT account or API key."
  fi

  if bool_is_true "$INSTALL_CLAUDE_CODE"; then
    install_npm_global "@anthropic-ai/claude-code" "claude" "Claude Code"
    append_next_step "Run 'claude' once and complete the sign-in flow."
  fi
}

_require_sudo_or_skip() {
  # Small guard used by the two privileged steps below.  Returns 0 if the
  # cached sudo session from ensure_sudo_session is usable, otherwise warns
  # with the caller-supplied step label and returns 1 so the caller can skip.
  local step_label="$1"
  if [ "$HAVE_SUDO" -eq 1 ]; then
    return 0
  fi
  warn "Skipping $step_label because sudo access is unavailable."
  return 1
}

maybe_configure_sudo_timestamp_timeout() {
  # Increase sudo's cached credential lifetime system-wide through a dedicated,
  # validated sudoers.d drop-in.  This reduces repeated password prompts both
  # during the bootstrap and in later day-to-day macOS terminal work.
  local sudoers_dir="/etc/sudoers.d"
  local target_file="$sudoers_dir/pcprep-timestamp-timeout"
  local desired_line
  local temp_file

  if ! bool_is_true "$CONFIGURE_SUDO_TIMESTAMP_TIMEOUT"; then
    return 0
  fi
  _require_sudo_or_skip "sudo timeout configuration" || return 0

  case "$SUDO_TIMESTAMP_TIMEOUT_MINUTES" in
    ''|*[!0-9]*)
      die "SUDO_TIMESTAMP_TIMEOUT_MINUTES must be a non-negative integer. Got: $SUDO_TIMESTAMP_TIMEOUT_MINUTES"
      ;;
  esac

  desired_line="Defaults timestamp_timeout=$SUDO_TIMESTAMP_TIMEOUT_MINUTES"

  if [ -f "$target_file" ] && grep -Fqx "$desired_line" "$target_file"; then
    log "Global sudo credential timeout is already set to $SUDO_TIMESTAMP_TIMEOUT_MINUTES minutes."
    return 0
  fi

  temp_file="$(mktemp "${TMPDIR:-/tmp}/pcprep-sudoers.XXXXXX")"
  printf '%s\n' "$desired_line" > "$temp_file"

  if ! /usr/sbin/visudo -cf "$temp_file" >/dev/null 2>&1; then
    rm -f "$temp_file"
    die "Refusing to install invalid sudoers content for timestamp_timeout."
  fi

  log "Setting global sudo credential timeout to $SUDO_TIMESTAMP_TIMEOUT_MINUTES minutes."
  run_sudo mkdir -p "$sudoers_dir"
  run_sudo install -m 0440 "$temp_file" "$target_file"
  rm -f "$temp_file"
}

maybe_enable_touch_id_for_sudo() {
  # Authorize Touch ID for sudo by adding "auth sufficient pam_tid.so" to
  # /etc/pam.d/sudo_local, Apple's upgrade-safe overlay over /etc/pam.d/sudo.
  # Editing sudo_local (rather than sudo itself) survives macOS upgrades.
  if ! bool_is_true "$ENABLE_TOUCH_ID_FOR_SUDO"; then
    return 0
  fi
  _require_sudo_or_skip "Touch ID for sudo" || return 0

  if [ ! -f /etc/pam.d/sudo_local.template ]; then
    warn "This macOS version does not expose /etc/pam.d/sudo_local.template. Skipping Touch ID setup."
    return 0
  fi

  if [ ! -f /etc/pam.d/sudo_local ]; then
    log "Creating /etc/pam.d/sudo_local from Apple's template."
    run_sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
  fi

  # Idempotent: only append if no existing "auth sufficient pam_tid.so" line
  # is present (whitespace-tolerant match).
  if grep -Eq '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so' /etc/pam.d/sudo_local; then
    log "Touch ID for sudo is already configured."
  else
    log "Enabling Touch ID for sudo prompts."
    printf '%s\n' 'auth       sufficient     pam_tid.so' | run_sudo tee -a /etc/pam.d/sudo_local >/dev/null
  fi
}

maybe_enable_firewall() {
  # Turn on the macOS application firewall (socketfilterfw) and, if explicitly
  # requested, stealth mode (no ICMP responses to unsolicited probes).  Both
  # settings are fully reversible via the same CLI with --setglobalstate off
  # / --setstealthmode off.
  if ! bool_is_true "$ENABLE_FIREWALL"; then
    return 0
  fi
  _require_sudo_or_skip "firewall configuration" || return 0

  log "Ensuring the macOS application firewall is enabled."
  run_sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null

  if bool_is_true "$ENABLE_FIREWALL_STEALTH"; then
    log "Enabling firewall stealth mode."
    run_sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on >/dev/null
  fi
}

main() {
  local verify_expect_mlx
  local verify_expect_powerlevel10k
  local verify_expect_sudo_timestamp_timeout

  require_macos
  ensure_existing_ssh_setup
  apply_shared_ssh_permissions

  if ! bool_is_true "$NO_NET" && ! has_internet; then
    warn "Internet connectivity was not detected. Switching to NO_NET=1 and running local-only steps."
    NO_NET=1
  fi

  if ! bool_is_true "$NO_NET"; then
    ensure_xcode_clt
  fi

  collect_preflight_inputs
  persist_preflight_git_identity

  if ensure_sudo_session; then
    HAVE_SUDO=1
    start_sudo_keepalive
    maybe_configure_sudo_timestamp_timeout
  fi

  if ! bool_is_true "$NO_NET"; then
    ensure_homebrew
    maybe_update_brew
    install_brew_bundle_file "$SCRIPT_DIR/Brewfile.core" "core CLI packages"

    # Install the AI-focused CLIs/apps immediately after the core CLI bundle so
    # they are available early if a later setup step needs interactive
    # debugging or investigation on the same machine.
    maybe_install_ai_clis
    maybe_install_github_copilot_cli
    maybe_install_ai_apps

    if bool_is_true "$INSTALL_GUI_APPS"; then
      install_core_gui_apps
      maybe_link_vscode_cli
    fi

    maybe_install_docker
    # Optional installs.  All INSTALL_* flags default to 1; Miniconda is
    # installed by default but kept dormant.  Group formulas-first so the
    # longer download queue runs together.
    maybe_install_extra_clis
    maybe_install_llama_cpp
    maybe_install_go
    maybe_install_miniconda
    maybe_install_ollama
    maybe_install_tailscale
    maybe_install_rust
    maybe_install_dev_fonts
    maybe_install_powerlevel10k
    maybe_install_firefox
    maybe_install_chrome
  else
    warn "Skipping network-backed installs because NO_NET=1."
  fi

  configure_git
  configure_azure_cli

  if bool_is_true "$APPLY_MACOS_DEFAULTS"; then
    "$SCRIPT_DIR/apply_defaults.sh"
  fi

  # Layer opinionated dotfiles (tmux / claude / codex / managed zsh) AFTER
  # the system defaults pass so nothing in apply_defaults.sh can overwrite
  # files we just staged.
  if bool_is_true "$APPLY_DOTFILES"; then
    "$SCRIPT_DIR/apply_dotfiles.sh"
  fi

  maybe_enable_touch_id_for_sudo
  maybe_enable_firewall

  if bool_is_true "$INSTALL_AI_ENV" && ! bool_is_true "$NO_NET"; then
    "$SCRIPT_DIR/setup_python_ai.sh"
    append_next_step "Open a new shell so the managed 'main' Python environment at $(default_main_venv_dir) auto-activates. Use 'mainoff' to return to plain Homebrew Python, 'mainon' to re-enter it, and 'condaon' when you want Miniconda instead."
  elif bool_is_true "$INSTALL_AI_ENV"; then
    warn "Skipping managed 'main' Python environment installation because NO_NET=1."
  fi

  append_next_step "Run 'gh auth login' if you want GitHub CLI authentication and git credential helpers to work immediately."
  append_next_step "Run 'az login' if you want Azure CLI authentication. Azure CLI dynamic extension installs are preconfigured to use your user-scoped macOS directory."
  append_next_step "If you need the full Apple SDKs for iOS or simulator work, install Xcode from the App Store and then run 'sudo xcodebuild -license accept'."
  append_next_step "Add Terminal or iTerm2 to Full Disk Access if a tool needs broader filesystem visibility."

  if ! bool_is_true "$APPLY_DOTFILES"; then
    append_next_step "Open a new terminal (or source ~/.config/pcprep/macos-shellenv.sh) so Homebrew, ~/.local/bin, and cargo PATH changes are active in future shells."
    if bool_is_true "$USE_POWERLEVEL10K_PROMPT"; then
      append_next_step "USE_POWERLEVEL10K_PROMPT=1 was requested, but APPLY_DOTFILES=0 leaves your existing ~/.zshrc untouched. Re-run with APPLY_DOTFILES=1 if you want pcprep to manage and enable the Powerlevel10k prompt for zsh."
    fi
  fi

  verify_expect_mlx="$INSTALL_MLX"
  if [ "$(uname -m)" != "arm64" ]; then
    verify_expect_mlx=0
  fi

  verify_expect_powerlevel10k=0
  if bool_is_true "$USE_POWERLEVEL10K_PROMPT" && bool_is_true "$APPLY_DOTFILES"; then
    verify_expect_powerlevel10k=1
  fi

  verify_expect_sudo_timestamp_timeout=0
  if bool_is_true "$CONFIGURE_SUDO_TIMESTAMP_TIMEOUT" && [ "$HAVE_SUDO" -eq 1 ]; then
    verify_expect_sudo_timestamp_timeout=1
  fi

  if ! bool_is_true "$NO_NET"; then
    EXPECT_GUI_APPS="$INSTALL_GUI_APPS" \
    EXPECT_DOCKER="$INSTALL_DOCKER" \
    EXPECT_GITHUB_COPILOT_CLI="$INSTALL_GITHUB_COPILOT_CLI" \
    EXPECT_CODEX_APP="$INSTALL_CODEX_APP" \
    EXPECT_CLAUDE_APP="$INSTALL_CLAUDE_APP" \
    EXPECT_CODEX="$INSTALL_CODEX" \
    EXPECT_CLAUDE="$INSTALL_CLAUDE_CODE" \
    EXPECT_AI_ENV="$INSTALL_AI_ENV" \
    EXPECT_MINICONDA="$INSTALL_MINICONDA" \
    EXPECT_DOTFILES="$APPLY_DOTFILES" \
    EXPECT_POWERLEVEL10K="$verify_expect_powerlevel10k" \
    EXPECT_OLLAMA="$INSTALL_OLLAMA" \
    EXPECT_DEV_FONTS="$INSTALL_DEV_FONTS" \
    EXPECT_RUST="$INSTALL_RUST" \
    EXPECT_GO="$INSTALL_GO" \
    EXPECT_TAILSCALE="$INSTALL_TAILSCALE" \
    EXPECT_MLX="$verify_expect_mlx" \
    EXPECT_LLAMA_CPP="$INSTALL_LLAMA_CPP" \
    EXPECT_EXTRA_CLIS="$INSTALL_EXTRA_CLIS" \
    EXPECT_FIREFOX="$INSTALL_FIREFOX" \
    EXPECT_CHROME="$INSTALL_CHROME" \
    EXPECT_SUDO_TIMESTAMP_TIMEOUT="$verify_expect_sudo_timestamp_timeout" \
    SUDO_TIMESTAMP_TIMEOUT_MINUTES="$SUDO_TIMESTAMP_TIMEOUT_MINUTES" \
    "$SCRIPT_DIR/verify_setup.sh"
  fi

  print_next_steps
  log "Bootstrap completed."
}

main "$@"
