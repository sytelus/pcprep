#!/usr/bin/env bash
# Apply a conservative set of macOS developer defaults.
# Every setting here is intentionally reversible and chosen to solve a real,
# common annoyance for developers rather than express a personal aesthetic.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mac/common.sh
source "$SCRIPT_DIR/common.sh"

# Install the ERR trap *after* sourcing common.sh so on_err is always defined.
trap 'on_err "${BASH_COMMAND}" "${LINENO}" "$?"' ERR

require_macos

log "Applying developer-friendly macOS defaults."

# Coding on macOS is painful if smart punctuation or auto-correction rewrites
# shell commands, JSON, or code literals. Disable the text substitutions that
# routinely break code across editors, terminals, and system text fields.
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Developers typically prefer responsive key repeat and Vim-friendly behavior
# over the accent picker that macOS shows on long key presses.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Finder is much more useful when it exposes file extensions, path context, and
# the current-folder search scope instead of hiding important filesystem details.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Developers routinely need to see and edit dotfiles such as .gitignore, .env,
# and .DS_Store.  Toggling Cmd+Shift+. per window is tedious, so surface them
# by default.  (Revert with revert_defaults.sh if you prefer a tidier Finder.)
defaults write com.apple.finder AppleShowAllFiles -bool true

# Render the full POSIX path of the current directory in every Finder window's
# title bar.  Complements the already-enabled pathbar and removes ambiguity
# when several Finder windows are open at once.
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Avoid polluting network and removable drives with Finder metadata files.
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Save panels are easier to work with when expanded by default.
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Keep the Dock a little less noisy without changing major layout behavior.
defaults write com.apple.dock show-recents -bool false

# A dedicated screenshots directory keeps the Desktop from turning into a dump.
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
defaults write com.apple.screencapture disable-shadow -bool true

# Restart the affected UI services so the settings take effect immediately.
killall Finder >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true

log "macOS defaults applied."
