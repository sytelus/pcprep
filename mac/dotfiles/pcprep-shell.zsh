# Managed by pcprep — sourced from ~/.zshrc via a fenced managed block.
# This file is REWRITTEN on every run of apply_dotfiles.sh.  Do not edit by
# hand; instead, edit mac/dotfiles/pcprep-shell.zsh in the repo.
#
# Philosophy: we never own the user's ~/.zshrc.  This file only layers
# opinionated extras (history, AI cache env vars, aliases) on top of
# whatever the user already has.  Removing the managed block from .zshrc
# fully uninstalls these customizations — no residual side effects.
#
# Target shell: zsh 5.9 (Sonoma default) on macOS.  Bash gets a separate
# managed fragment at ~/.config/pcprep/pcprep-shell.bash.


# --- History -----------------------------------------------------------
# Zsh's default HISTSIZE/SAVEHIST on macOS is tiny (1000).  Long training
# runs, Claude Code sessions, and multi-day debugging campaigns routinely
# overflow that, so bump both to 10,000 entries.
export HISTSIZE=10000
export SAVEHIST=10000
# Pin the history file to a known location so `history` works consistently
# whether the shell is launched from Terminal, iTerm2, or VS Code.
export HISTFILE="${HISTFILE:-$HOME/.zsh_history}"

if [ -n "${ZSH_VERSION:-}" ]; then
  # Flush each command to $HISTFILE immediately and re-read the file so new
  # tabs see commands typed in older tabs without waiting for shell exit.
  setopt INC_APPEND_HISTORY
  setopt SHARE_HISTORY

  # Drop consecutive duplicates and any older duplicates of the current
  # command — keeps `history` concise and arrow-up useful.
  setopt HIST_IGNORE_DUPS
  setopt HIST_IGNORE_ALL_DUPS
  setopt HIST_FIND_NO_DUPS

  # Commands typed with a leading space are not saved.  Handy for one-off
  # entries containing secrets or tokens.
  setopt HIST_IGNORE_SPACE

  # Record the timestamp of each entry so `history -i` shows when commands
  # were run.  Useful for reconstructing a session post-hoc.
  setopt EXTENDED_HISTORY

  # Keep the default zsh prompt intentionally short: just a compact path
  # showing the last two components plus the standard prompt char.
  PROMPT='%2~ %# '
  RPROMPT=
fi

# Shell-agnostic environment, aliases, and SSH/tmux helpers live in a common
# fragment so macOS bash and zsh share the same day-to-day development setup.
if [ -f "$HOME/.config/pcprep/pcprep-shell.common.sh" ]; then
  . "$HOME/.config/pcprep/pcprep-shell.common.sh"
fi
