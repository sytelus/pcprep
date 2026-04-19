#!/usr/bin/env bash
# Conservative bootstrap for a new macOS developer machine.
# Design goals:
# - Safe to re-run after partial setup or failure
# - Avoid invasive shell rewrites and highly personal tooling choices
# - Install the minimum trusted set that materially improves macOS for developers
# - Prepare a dependable Python and Node base for AI development workflows

set -Eeuo pipefail
trap 'on_err "${BASH_COMMAND}" "${LINENO}" "$?"' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mac/common.sh
source "$SCRIPT_DIR/common.sh"

NO_NET="${NO_NET:-0}"
SKIP_BREW_UPDATE="${SKIP_BREW_UPDATE:-0}"
INSTALL_GUI_APPS="${INSTALL_GUI_APPS:-1}"
INSTALL_DOCKER="${INSTALL_DOCKER:-1}"
INSTALL_CODEX="${INSTALL_CODEX:-1}"
INSTALL_CLAUDE_CODE="${INSTALL_CLAUDE_CODE:-1}"
INSTALL_AI_ENV="${INSTALL_AI_ENV:-1}"
APPLY_MACOS_DEFAULTS="${APPLY_MACOS_DEFAULTS:-1}"
ENABLE_FIREWALL="${ENABLE_FIREWALL:-1}"
ENABLE_FIREWALL_STEALTH="${ENABLE_FIREWALL_STEALTH:-0}"
ENABLE_TOUCH_ID_FOR_SUDO="${ENABLE_TOUCH_ID_FOR_SUDO:-1}"
UPGRADE_NODE_GLOBALS="${UPGRADE_NODE_GLOBALS:-0}"

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
  local preferred_prefix
  local brew_bin
  local brew_shellenv_file
  local shellenv_block
  local zprofile_source_line
  local bash_profile_source_line

  preferred_prefix="$(brew_prefix_guess)"
  brew_bin="$preferred_prefix/bin/brew"

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
if [ -x \"$brew_bin\" ]; then
  eval \"\$($brew_bin shellenv)\"
fi

export PATH=\"\$HOME/.local/bin:\$PATH\"

# Rust toolchain: picked up automatically when pcprep's maybe_install_rust
# has populated ~/.cargo/bin.  Keeping the check here avoids editing the
# user's ~/.zshrc / ~/.bash_profile to add cargo manually.
if [ -d \"\$HOME/.cargo/bin\" ]; then
  export PATH=\"\$HOME/.cargo/bin:\$PATH\"
fi"
  upsert_managed_block \
    "$brew_shellenv_file" \
    "# >>> pcprep macos shellenv >>>" \
    "# <<< pcprep macos shellenv <<<" \
    "$shellenv_block"

  zprofile_source_line='[ -f "$HOME/.config/pcprep/macos-shellenv.sh" ] && source "$HOME/.config/pcprep/macos-shellenv.sh"'
  bash_profile_source_line='[ -f "$HOME/.config/pcprep/macos-shellenv.sh" ] && source "$HOME/.config/pcprep/macos-shellenv.sh"'
  ensure_line_in_file "$HOME/.zprofile" "$zprofile_source_line"
  ensure_line_in_file "$HOME/.bash_profile" "$bash_profile_source_line"
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

  if brew list --cask docker >/dev/null 2>&1; then
    log "Docker Desktop is already installed."
  else
    log "Installing Docker Desktop."
    brew install --cask docker
  fi

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

maybe_install_extra_clis() {
  # Small bundle of quality-of-life CLIs and one utility cask.  All are dormant
  # when not invoked, so installing them has no idle cost.
  if ! bool_is_true "$INSTALL_EXTRA_CLIS"; then
    warn "INSTALL_EXTRA_CLIS=0 set. Skipping extra CLI bundle."
    return 0
  fi

  # TUI disk usage explorer; complements 'du' and 'btop' for storage triage.
  brew_install_if_missing formula ncdu "ncdu"
  # CPU/memory/IO benchmark for quick machine sanity checks.
  brew_install_if_missing formula sysbench "sysbench"
  # Host-to-host network throughput testing for distributed workloads.
  brew_install_if_missing formula iperf3 "iperf3"
  # GUI-driven app uninstaller.  Its optional "SmartDelete" helper is dormant
  # until enabled in-app, so installing the cask costs effectively nothing.
  brew_install_if_missing cask appcleaner "AppCleaner"
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

maybe_install_ollama() {
  # Install Ollama's FORMULA (CLI binary), NOT the cask (GUI app).  The cask
  # ships a login item that starts the Ollama server every time the user logs
  # in, which costs battery even when no model is loaded.  The formula installs
  # just the binaries; the server only runs when the user invokes
  # `ollama serve` explicitly, which matches the "no unexpected background
  # daemons" goal set in mac/todo.md.
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
}

maybe_install_firefox() {
  # Firefox cask.  Mozilla Maintenance Service is dormant unless Firefox is
  # running, so installing the cask has no idle cost.
  if ! bool_is_true "$INSTALL_FIREFOX"; then
    warn "INSTALL_FIREFOX=0 set. Skipping Firefox."
    return 0
  fi
  brew_install_if_missing cask firefox "Firefox"
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
  brew_install_if_missing cask google-chrome "Google Chrome"
  append_next_step "Chrome installs Google's Keystone auto-updater as a persistent launchd agent that runs even when Chrome is quit. If you rarely use Chrome, you can set 'defaults write com.google.Keystone.Agent checkInterval 0' to pause its polling."
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

configure_git() {
  local gitignore_file
  local existing_name
  local existing_email

  if ! command_exists git; then
    warn "Git is not available yet. Skipping Git configuration."
    return 0
  fi

  log "Applying conservative global Git defaults."
  git config --global init.defaultBranch main
  git config --global pull.rebase true
  git config --global fetch.prune true
  git config --global diff.colorMoved zebra
  git config --global credential.helper osxkeychain
  git config --global core.eol lf
  git config --global core.autocrlf input

  if command_exists code; then
    git config --global core.editor "code --wait"
  fi

  gitignore_file="$HOME/.gitignore_global"
  ensure_line_in_file "$gitignore_file" ".DS_Store"
  ensure_line_in_file "$gitignore_file" ".Trash-*"
  git config --global core.excludesfile "$gitignore_file"

  if command_exists git-lfs; then
    # git lfs install writes the expected global filters once and is safe to rerun.
    git lfs install --skip-repo >/dev/null
  fi

  existing_name="$(git config --global --get user.name || true)"
  existing_email="$(git config --global --get user.email || true)"

  if [ -z "$existing_name" ] && [ -n "$user_name" ]; then
    git config --global user.name "$user_name"
  elif [ -z "$existing_name" ] && is_interactive; then
    printf 'Git user.name is not set. Enter your name (leave blank to skip): '
    read -r user_name
    if [ -n "$user_name" ]; then
      git config --global user.name "$user_name"
    fi
  fi

  if [ -z "$existing_email" ] && [ -n "$user_email" ]; then
    git config --global user.email "$user_email"
  elif [ -z "$existing_email" ] && is_interactive; then
    printf 'Git user.email is not set. Enter your email (leave blank to skip): '
    read -r user_email
    if [ -n "$user_email" ]; then
      git config --global user.email "$user_email"
    fi
  fi
}

configure_ssh_keychain_support() {
  local ssh_dir
  local ssh_config

  ssh_dir="$HOME/.ssh"
  ssh_config="$ssh_dir/config"

  ensure_dir "$ssh_dir"
  chmod 700 "$ssh_dir"

  if [ -f "$ssh_config" ]; then
    warn "Existing ~/.ssh/config detected. Leaving it unchanged to avoid overriding host-specific rules."
    append_next_step "If you want macOS to remember SSH key passphrases, add 'AddKeysToAgent yes' and 'UseKeychain yes' to ~/.ssh/config."
    return 0
  fi

  log "Creating a minimal SSH config that works well with the macOS keychain."
  cat > "$ssh_config" <<'EOF'
Host *
    IgnoreUnknown UseKeychain
    AddKeysToAgent yes
    UseKeychain yes
EOF
  chmod 600 "$ssh_config"
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

maybe_enable_touch_id_for_sudo() {
  if ! bool_is_true "$ENABLE_TOUCH_ID_FOR_SUDO"; then
    return 0
  fi

  if [ "$HAVE_SUDO" -ne 1 ]; then
    warn "Skipping Touch ID for sudo because sudo access is unavailable."
    return 0
  fi

  if [ ! -f /etc/pam.d/sudo_local.template ]; then
    warn "This macOS version does not expose /etc/pam.d/sudo_local.template. Skipping Touch ID setup."
    return 0
  fi

  if [ ! -f /etc/pam.d/sudo_local ]; then
    log "Creating /etc/pam.d/sudo_local from Apple's template."
    run_sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
  fi

  if grep -Eq '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so' /etc/pam.d/sudo_local; then
    log "Touch ID for sudo is already configured."
  else
    log "Enabling Touch ID for sudo prompts."
    printf '%s\n' 'auth       sufficient     pam_tid.so' | run_sudo tee -a /etc/pam.d/sudo_local >/dev/null
  fi
}

maybe_enable_firewall() {
  if ! bool_is_true "$ENABLE_FIREWALL"; then
    return 0
  fi

  if [ "$HAVE_SUDO" -ne 1 ]; then
    warn "Skipping firewall configuration because sudo access is unavailable."
    return 0
  fi

  log "Ensuring the macOS application firewall is enabled."
  run_sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null

  if bool_is_true "$ENABLE_FIREWALL_STEALTH"; then
    log "Enabling firewall stealth mode."
    run_sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on >/dev/null
  fi
}

main() {
  require_macos

  if ! bool_is_true "$NO_NET" && ! has_internet; then
    warn "Internet connectivity was not detected. Switching to NO_NET=1 and running local-only steps."
    NO_NET=1
  fi

  if ensure_sudo_session; then
    HAVE_SUDO=1
  fi

  if ! bool_is_true "$NO_NET"; then
    ensure_xcode_clt
    ensure_homebrew
    maybe_update_brew
    install_brew_bundle_file "$SCRIPT_DIR/Brewfile.core" "core CLI packages"

    if bool_is_true "$INSTALL_GUI_APPS"; then
      install_brew_bundle_file "$SCRIPT_DIR/Brewfile.cask" "core GUI applications"
      maybe_link_vscode_cli
    fi

    maybe_install_docker
    # Opt-in-by-default installs (all INSTALL_* flags default to 1).  Grouped
    # formulas-first, casks-second so the longer download queue runs together.
    maybe_install_extra_clis
    maybe_install_llama_cpp
    maybe_install_go
    maybe_install_ollama
    maybe_install_tailscale
    maybe_install_rust
    maybe_install_dev_fonts
    maybe_install_firefox
    maybe_install_chrome
    maybe_install_ai_clis
  else
    warn "Skipping network-backed installs because NO_NET=1."
  fi

  configure_git
  configure_ssh_keychain_support

  if bool_is_true "$APPLY_MACOS_DEFAULTS"; then
    "$SCRIPT_DIR/apply_defaults.sh"
  fi

  maybe_enable_touch_id_for_sudo
  maybe_enable_firewall

  if bool_is_true "$INSTALL_AI_ENV" && ! bool_is_true "$NO_NET"; then
    "$SCRIPT_DIR/setup_python_ai.sh"
  elif bool_is_true "$INSTALL_AI_ENV"; then
    warn "Skipping AI environment creation because NO_NET=1."
  fi

  append_next_step "Run 'gh auth login' if you want GitHub CLI authentication and git credential helpers to work immediately."
  append_next_step "If you need the full Apple SDKs for iOS or simulator work, install Xcode from the App Store and then run 'sudo xcodebuild -license accept'."
  append_next_step "Add Terminal or iTerm2 to Full Disk Access if a tool needs broader filesystem visibility."

  if bool_is_true "$INSTALL_GUI_APPS"; then
    append_next_step "Restart your terminal after setup so the managed PATH changes are active in all future shells."
  fi

  if ! bool_is_true "$NO_NET"; then
    EXPECT_GUI_APPS="$INSTALL_GUI_APPS" \
    EXPECT_DOCKER="$INSTALL_DOCKER" \
    EXPECT_CODEX="$INSTALL_CODEX" \
    EXPECT_CLAUDE="$INSTALL_CLAUDE_CODE" \
    EXPECT_AI_ENV="$INSTALL_AI_ENV" \
    EXPECT_OLLAMA="$INSTALL_OLLAMA" \
    EXPECT_DEV_FONTS="$INSTALL_DEV_FONTS" \
    EXPECT_RUST="$INSTALL_RUST" \
    EXPECT_GO="$INSTALL_GO" \
    EXPECT_TAILSCALE="$INSTALL_TAILSCALE" \
    EXPECT_MLX="$INSTALL_MLX" \
    EXPECT_LLAMA_CPP="$INSTALL_LLAMA_CPP" \
    EXPECT_EXTRA_CLIS="$INSTALL_EXTRA_CLIS" \
    EXPECT_FIREFOX="$INSTALL_FIREFOX" \
    EXPECT_CHROME="$INSTALL_CHROME" \
    "$SCRIPT_DIR/verify_setup.sh"
  fi

  print_next_steps
  log "Bootstrap completed."
}

main "$@"
