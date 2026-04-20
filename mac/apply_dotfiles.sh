#!/usr/bin/env bash
# Install shared cross-platform dotfiles from ubuntu/ into the user's home
# directory, plus a managed macOS-specific zsh fragment that layers
# opinionated history/aliases/env-vars on top of the user's existing ~/.zshrc.
#
# Policy:
# - Never clobber an existing user-edited config.  Files in ~/ that the user
#   may have customized (.tmux.conf, ~/.claude/settings.json,
#   ~/.codex/config.toml) are copied COPY-IF-ABSENT.
# - The pcprep-shell.zsh fragment IS rewritten on every run because it lives
#   under ~/.config/pcprep/ (a directory we own) and is sourced from a fenced
#   managed block in ~/.zshrc — removing that block fully uninstalls us.
# - All changes are reversible without this script by:
#     1. Deleting ~/.config/pcprep/pcprep-shell.zsh
#     2. Removing the "# >>> pcprep macos zshrc >>>" block from ~/.zshrc
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

# ------------------------------------------------------ Managed zsh fragment

# Our opinionated zsh extras (history tuning, AI cache env vars, aliases).
# This file lives under ~/.config/pcprep/ — a directory we own — so we are
# free to REWRITE it on every run.  The user's ~/.zshrc gets a single
# fenced block that sources it; deleting that block fully removes us.
PCPREP_SHELL_DEST="$HOME/.config/pcprep/pcprep-shell.zsh"
ensure_dir "$(dirname "$PCPREP_SHELL_DEST")"
cp "$MAC_DOTFILES_DIR/pcprep-shell.zsh" "$PCPREP_SHELL_DEST"
log "Wrote managed zsh fragment to $PCPREP_SHELL_DEST"

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

append_next_step "Dotfiles applied. Open a new terminal (or 'exec zsh') so the updated ~/.zshrc takes effect. The managed block is marked by '>>> pcprep macos zshrc >>>' / '<<< pcprep macos zshrc <<<'; remove that block to uninstall."

log "Dotfiles setup completed."
