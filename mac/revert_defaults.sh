#!/usr/bin/env bash
# Revert the macOS defaults changed by apply_defaults.sh back to system defaults.
# This does not attempt to restore a user's previous custom state. It simply
# removes the managed preference keys so macOS falls back to its defaults.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mac/common.sh
source "$SCRIPT_DIR/common.sh"

# Install the ERR trap *after* sourcing common.sh so on_err is always defined.
trap 'on_err "${BASH_COMMAND}" "${LINENO}" "$?"' ERR

require_macos

log "Reverting managed macOS defaults to system defaults."

defaults delete NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled >/dev/null 2>&1 || true
defaults delete NSGlobalDomain NSAutomaticDashSubstitutionEnabled >/dev/null 2>&1 || true
defaults delete NSGlobalDomain NSAutomaticSpellingCorrectionEnabled >/dev/null 2>&1 || true
defaults delete NSGlobalDomain NSAutomaticCapitalizationEnabled >/dev/null 2>&1 || true
defaults delete NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled >/dev/null 2>&1 || true
defaults delete NSGlobalDomain ApplePressAndHoldEnabled >/dev/null 2>&1 || true
defaults delete NSGlobalDomain KeyRepeat >/dev/null 2>&1 || true
defaults delete NSGlobalDomain InitialKeyRepeat >/dev/null 2>&1 || true
defaults delete NSGlobalDomain AppleShowAllExtensions >/dev/null 2>&1 || true

defaults delete com.apple.finder ShowPathbar >/dev/null 2>&1 || true
defaults delete com.apple.finder ShowStatusBar >/dev/null 2>&1 || true
defaults delete com.apple.finder FXDefaultSearchScope >/dev/null 2>&1 || true
defaults delete com.apple.finder FXEnableExtensionChangeWarning >/dev/null 2>&1 || true
defaults delete com.apple.finder FXPreferredViewStyle >/dev/null 2>&1 || true
defaults delete com.apple.finder _FXSortFoldersFirst >/dev/null 2>&1 || true
defaults delete com.apple.finder AppleShowAllFiles >/dev/null 2>&1 || true
defaults delete com.apple.finder _FXShowPosixPathInTitle >/dev/null 2>&1 || true

defaults delete com.apple.desktopservices DSDontWriteNetworkStores >/dev/null 2>&1 || true
defaults delete com.apple.desktopservices DSDontWriteUSBStores >/dev/null 2>&1 || true

defaults delete NSGlobalDomain NSNavPanelExpandedStateForSaveMode >/dev/null 2>&1 || true
defaults delete NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 >/dev/null 2>&1 || true

defaults delete com.apple.dock show-recents >/dev/null 2>&1 || true

defaults delete com.apple.screencapture location >/dev/null 2>&1 || true
defaults delete com.apple.screencapture disable-shadow >/dev/null 2>&1 || true

killall Finder >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true

log "Managed macOS defaults reverted."
