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
user_name="${user_name:-}"
user_email="${user_email:-}"

NEXT_STEPS=()
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

export PATH=\"\$HOME/.local/bin:\$PATH\""
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
  brew bundle --file="$bundle_file" --no-lock --no-upgrade
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
    "$SCRIPT_DIR/verify_setup.sh"
  fi

  print_next_steps
  log "Bootstrap completed."
}

main "$@"
