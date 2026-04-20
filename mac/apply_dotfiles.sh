#!/usr/bin/env bash
# Install shared cross-platform dotfiles from ubuntu/ into the user's home
# directory, plus managed macOS shell fragments that layer opinionated
# history/aliases/env-vars on top of the user's existing bash/zsh setup.
#
# Policy:
# - Never clobber an existing user-edited config.  Files in ~/ that the user
#   may have customized (.tmux.conf, ~/.claude/settings.json,
#   ~/.codex/config.toml) are copied COPY-IF-ABSENT.
# - The managed shell fragments under ~/.config/pcprep/ ARE rewritten on every
#   run because they live in a directory we own and are sourced from fenced
#   managed blocks in ~/.zshrc / ~/.bashrc / ~/.bash_profile.
# - All changes are reversible without this script by:
#     1. Deleting ~/.config/pcprep/ managed shell files
#     2. Removing the "# >>> pcprep macos ... >>>" blocks from ~/.zshrc,
#        ~/.bashrc, and ~/.bash_profile
#     3. Deleting any copied-if-absent files you no longer want
#
# Runs under Bash 3.2 so it works on a fresh Mac before Homebrew is installed.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mac/common.sh
source "$SCRIPT_DIR/common.sh"

# Install the ERR trap *after* sourcing common.sh so on_err is always defined.
trap 'on_err "${BASH_COMMAND}" "${LINENO}" "$?"' ERR

require_macos

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MAC_DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
UBUNTU_DOTFILES_DIR="$REPO_ROOT/ubuntu"

if [ ! -d "$MAC_DOTFILES_DIR" ]; then
  die "macOS dotfiles directory not found at $MAC_DOTFILES_DIR"
fi

if [ ! -d "$UBUNTU_DOTFILES_DIR" ]; then
  die "Shared Ubuntu dotfiles directory not found at $UBUNTU_DOTFILES_DIR"
fi

# ------------------------------------------------------------------ helpers

# Copy a repo-managed file into ~/ only when no file is already there.  Prints a
# log line whichever way it goes so the user can see what we did/skipped.
#   $1: absolute source path inside the repo
#   $2: absolute destination path under $HOME
#   $3: human-readable label
copy_if_absent() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ ! -f "$src" ]; then
    warn "Repo-managed $label missing at $src; skipping."
    return 0
  fi

  if [ -e "$dst" ]; then
    log "$label already present at $dst — leaving it untouched."
    return 0
  fi

  ensure_dir "$(dirname "$dst")"
  cp "$src" "$dst"
  log "Installed $label at $dst."
}

# Copy a repo-managed file into ~/.local/bin only when no file is already
# there, then ensure the destination is executable.  This keeps parity with
# ubuntu/cp_dotfiles.sh while still honoring the "don't clobber user edits"
# rule used elsewhere in this script.
install_local_bin_asset() {
  local src="$1"
  local dst="$2"
  local label="$3"

  copy_if_absent "$src" "$dst" "$label"

  if [ -e "$dst" ] && [ ! -x "$dst" ]; then
    chmod +x "$dst"
    log "Marked $label executable at $dst."
  fi
}

# ----------------------------------------------------------- tmux config

# ~/.tmux.conf: fully portable between Linux and macOS.  Copy-if-absent so
# we never stomp on tmux tweaks a user has built up.
copy_if_absent \
  "$UBUNTU_DOTFILES_DIR/.tmux.conf" \
  "$HOME/.tmux.conf" \
  "tmux configuration"

# --------------------------------------------------------- Claude Code

# Claude Code stores per-user settings at ~/.claude/settings.json.  Seeds
# the documented pcprep defaults on a fresh machine; leaves any existing
# customization intact.
copy_if_absent \
  "$UBUNTU_DOTFILES_DIR/.claude/settings.json" \
  "$HOME/.claude/settings.json" \
  "Claude Code settings"

# ---------------------------------------------------------- Codex CLI

# Codex reads ~/.codex/config.toml.  Port the same reasoning-effort /
# sandbox preferences the Linux box uses so cross-platform behavior stays
# consistent.  Copy-if-absent.
copy_if_absent \
  "$UBUNTU_DOTFILES_DIR/.codex/config.toml" \
  "$HOME/.codex/config.toml" \
  "Codex CLI configuration"

# --------------------------------------------------------- Readline config

# Readline config helps bash and other Readline-based CLIs feel the same on
# Ubuntu and macOS without affecting zsh's line editor.
copy_if_absent \
  "$UBUNTU_DOTFILES_DIR/.inputrc" \
  "$HOME/.inputrc" \
  "Readline configuration"

# --------------------------------------------------------- Local bin helpers

# Cross-machine helper scripts copied from ubuntu/ into ~/.local/bin.  Most of
# these are Linux-oriented and may only be useful when the same home directory
# or repo is shared with Linux hosts, but copying them here is harmless and
# keeps the per-user toolbox consistent across machines.
for local_bin_file in \
  rundocker.sh \
  azmount.yaml \
  azmount.sh \
  mount_cifs.sh \
  start_tmux.sh \
  sysinfo.sh \
  treesize.sh \
  measure_flops.py \
  kill_vscode_srv.sh \
  security_status.sh \
  unban.sh
do
  install_local_bin_asset \
    "$UBUNTU_DOTFILES_DIR/$local_bin_file" \
    "$HOME/.local/bin/$local_bin_file" \
    "$local_bin_file"
done

# ---------------------------------------------------- Managed shell fragments

# The mac shell fragments live under ~/.config/pcprep, which we own.  That lets
# us rewrite them on reruns while still keeping ~/.zshrc, ~/.bashrc, and
# ~/.bash_profile under the user's control except for small fenced blocks.
PCPREP_CONFIG_DIR="$HOME/.config/pcprep"
ensure_dir "$PCPREP_CONFIG_DIR"

cp "$MAC_DOTFILES_DIR/pcprep-shell.zsh" "$PCPREP_CONFIG_DIR/pcprep-shell.zsh"
cp "$MAC_DOTFILES_DIR/pcprep-shell.bash" "$PCPREP_CONFIG_DIR/pcprep-shell.bash"
cp "$MAC_DOTFILES_DIR/pcprep-shell.common.sh" "$PCPREP_CONFIG_DIR/pcprep-shell.common.sh"
cp "$UBUNTU_DOTFILES_DIR/.bash_aliases" "$PCPREP_CONFIG_DIR/pcprep-aliases.sh"
log "Wrote managed bash/zsh shell fragments under $PCPREP_CONFIG_DIR"

# The source line we want in ~/.zshrc.  The guard ensures zsh does not
# error out if the fragment is ever moved/deleted — sourcing silently
# no-ops in that case.
zshrc_source_line='[ -f "$HOME/.config/pcprep/pcprep-shell.zsh" ] && source "$HOME/.config/pcprep/pcprep-shell.zsh"'

# Use the upsert_managed_block helper so reruns replace the previous block
# in-place instead of appending duplicates.  The start/end markers make it
# trivial for a user to find and delete the block manually.
upsert_managed_block \
  "$HOME/.zshrc" \
  "# >>> pcprep macos zshrc >>>" \
  "# <<< pcprep macos zshrc <<<" \
  "$zshrc_source_line"
log "Ensured ~/.zshrc sources the pcprep managed fragment."

bashrc_source_line='[ -f "$HOME/.config/pcprep/pcprep-shell.bash" ] && . "$HOME/.config/pcprep/pcprep-shell.bash"'
upsert_managed_block \
  "$HOME/.bashrc" \
  "# >>> pcprep macos bashrc >>>" \
  "# <<< pcprep macos bashrc <<<" \
  "$bashrc_source_line"
log "Ensured ~/.bashrc sources the pcprep managed fragment."

# Login bash on macOS reads ~/.bash_profile, not ~/.bashrc, so source ~/.bashrc
# from a fenced block there as well.  The separate managed shellenv block from
# prepare_new_box.sh remains responsible for Homebrew PATH setup.
bash_profile_block='if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi'
upsert_managed_block \
  "$HOME/.bash_profile" \
  "# >>> pcprep macos bash_profile >>>" \
  "# <<< pcprep macos bash_profile <<<" \
  "$bash_profile_block"
log "Ensured ~/.bash_profile sources ~/.bashrc for login bash shells."

append_next_step "Dotfiles applied. Open a new terminal (or run 'exec zsh' / 'exec bash') so the updated shell fragments take effect. The managed blocks are marked by '>>> pcprep macos ... >>>' / '<<< pcprep macos ... <<<'; remove those blocks to uninstall."

log "Dotfiles setup completed."
