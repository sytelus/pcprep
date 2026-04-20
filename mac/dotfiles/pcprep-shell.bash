# Managed by pcprep — sourced from ~/.bashrc via a fenced managed block.
# This file is REWRITTEN on every run of apply_dotfiles.sh.  Do not edit by
# hand; instead, edit mac/dotfiles/pcprep-shell.bash in the repo.

case $- in
  *i*) ;;
  *) return 0 ;;
esac

# Bash history defaults on macOS are too small for long debugging sessions.
export HISTCONTROL=ignoreboth
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTFILE="${HISTFILE:-$HOME/.bash_history}"

shopt -s histappend
shopt -s checkwinsize
shopt -s extglob

PROMPT_DIRTRIM=1

# Preserve alias expansion after sudo, matching the Ubuntu setup.
alias sudo='sudo '

if [ -f "$HOME/.config/pcprep/macos-shellenv.sh" ]; then
  . "$HOME/.config/pcprep/macos-shellenv.sh"
fi

if [ -f "$HOME/.config/pcprep/pcprep-shell.common.sh" ]; then
  . "$HOME/.config/pcprep/pcprep-shell.common.sh"
fi

# Optional programmable completion, if the user later installs it.
if ! shopt -oq posix && command -v brew >/dev/null 2>&1; then
  _pcprep_brew_prefix="$(brew --prefix 2>/dev/null || true)"
  if [ -n "$_pcprep_brew_prefix" ] && [ -f "$_pcprep_brew_prefix/etc/profile.d/bash_completion.sh" ]; then
    . "$_pcprep_brew_prefix/etc/profile.d/bash_completion.sh"
  fi
  unset _pcprep_brew_prefix
fi

# Keep pressing Tab to cycle through completions, matching Ubuntu's behavior.
bind '"\t":menu-complete' 2>/dev/null || true
bind '"\e[Z":menu-complete-backward' 2>/dev/null || true

# Let a user-owned ~/.bash_aliases layer override or extend pcprep aliases.
if [ -f "$HOME/.bash_aliases" ]; then
  . "$HOME/.bash_aliases"
fi
