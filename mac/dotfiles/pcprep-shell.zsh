# Managed by pcprep — sourced from ~/.zshrc via a fenced managed block.
# This file is REWRITTEN on every run of apply_dotfiles.sh.  Do not edit by
# hand; instead, edit mac/dotfiles/pcprep-shell.zsh in the repo.
#
# Philosophy: we never own the user's ~/.zshrc.  This file only layers
# opinionated extras (history, AI cache env vars, aliases) on top of
# whatever the user already has.  Removing the managed block from .zshrc
# fully uninstalls these customizations — no residual side effects.
#
# Target shell: zsh 5.9 (Sonoma default) on macOS.  Bash users can source
# this file too, but the `setopt` block below will be silently ignored on
# non-zsh shells since we guard it with $ZSH_VERSION.


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
fi


# --- General environment ----------------------------------------------
# Deterministic Python dict/set ordering.  PYTHONHASHSEED=0 disables the
# random salt that Python adds to hash(), which matters for test repro
# and for any code that relies on iteration order being stable.
export PYTHONHASHSEED=0

# Silence git's "unsafe repository" warning when editing repos owned by a
# different UID — common on shared volumes, Docker bind-mounts, and
# external drives.  Does NOT affect git's actual safety checks, only the
# advisory warning.
export GIT_TEST_ASSUME_ALL_SAFE=1


# --- AI data / cache layout -------------------------------------------
# Centralize every AI tool's cache under a small number of roots so you
# can later relocate all of them to an external SSD by editing just these
# variables (no per-tool config to hunt down).
#
# Layout:
#   ~/data         datasets you own (pre-processed, curated)
#   ~/misc_caches  per-tool caches (HuggingFace, Tiktoken, W&B, etc.)
#   ~/models       model checkpoints / weights
#   ~/out_dir      training outputs, logs, artifacts
export DATA_ROOT="$HOME/data"
export CACHE_ROOT="$HOME/misc_caches"
export MODELS_ROOT="$HOME/models"
export OUT_DIR="$HOME/out_dir"

# HuggingFace Hub + Datasets cache.  Setting HF_HOME is the preferred
# single override since modern huggingface_hub versions derive the
# transformers / diffusers cache paths from it.
export HF_HOME="$CACHE_ROOT/hf_home"
export HF_DATASETS_CACHE="$CACHE_ROOT/datasets"

# OpenAI's tiktoken caches tokenizer downloads here; otherwise it writes
# into /tmp and re-downloads after reboots.
export TIKTOKEN_CACHE_DIR="$CACHE_ROOT/tiktoken_cache"

# Weights & Biases run cache (independent of the API key).
export WANDB_CACHE_DIR="$CACHE_ROOT/wandb_cache"

# Ollama model storage.  Only applied when OLLAMA is installed; otherwise
# harmlessly unused.
export OLLAMA_MODELS="$MODELS_ROOT/ollama"

# Create any missing cache directories the first time a new shell starts.
# Guarded with `[ -d ]` so we skip the mkdir on shells where the dir is
# already there (fast path for subsequent shells).
for _pcprep_dir in \
  "$DATA_ROOT" "$CACHE_ROOT" "$MODELS_ROOT" "$OUT_DIR" \
  "$HF_HOME" "$HF_DATASETS_CACHE" "$TIKTOKEN_CACHE_DIR" \
  "$WANDB_CACHE_DIR" "$OLLAMA_MODELS"; do
  [ -d "$_pcprep_dir" ] || mkdir -p "$_pcprep_dir"
done
unset _pcprep_dir


# --- Git aliases (portable; no git-side config needed) ---------------
# Short names, non-overloaded: `gstat` instead of `gs` so we do not shadow
# `ghostscript` on any path-conscious machine.
alias gstat='git status'
alias gdiff='git diff'
alias gpush='git push'
alias gpull='git pull'
alias gpullr='git pull --rebase'
alias glog='git log --pretty=oneline -n 10'
alias gchk='git checkout'
alias gcln='git clean -fdx'          # -f force, -d dirs, -x include .gitignored
alias gremote='git remote -v'
alias undocommit='git reset --soft HEAD~1'

# Stage everything and commit with a single-line message.
#   gcommit "fix: handle empty response"
gcommit() {
  git add -A && git commit -m "$1"
}

# Stage + commit + push in one call; default message "update" when empty.
#   checkin                   -> commits with message "update"
#   checkin wip notebooks     -> commits with message "wip notebooks"
checkin() {
  local msg="update"
  if [ "$#" -gt 0 ]; then msg="$*"; fi
  git add -A && git commit -m "$msg" && git push
}

# Create and check out a new branch.  Plain wrapper for discoverability.
gbra() { git checkout -b "$1"; }


# --- Screen / navigation helpers --------------------------------------
# Full-screen "reset" that also scrolls away any prior output; handy after
# a program leaves the terminal in a weird state.
alias cls='tput reset'

# Two-letter push/pop directory shortcuts.
alias pu='pushd .'
alias po='popd'


# --- rsync-based copy/move with a single progress line ----------------
# -a preserves attributes, -h human sizes, --info=progress2 collapses the
# usual per-file output into one rolling total-progress indicator.
alias cpx='rsync -avh --info=progress2'
alias cpz='rsync -avhz --info=progress2'                       # + compression (for slow links)
alias mvx='rsync -avh --remove-source-files --info=progress2'  # copy then delete source


# --- AI CLI conveniences ----------------------------------------------
# "yolo" aliases skip permission dialogs.  Useful for one-off scripted
# runs; do NOT use in environments where the agent could do something you
# would not let it do unattended.
alias claudeyolo='claude --dangerously-skip-permissions'
alias codexyolo='codex --yolo'

# Update aliases.  Claude Code self-updates; Codex reinstalls via npm.
# No sudo — brew's Node puts the global prefix under /opt/homebrew which
# is owned by the current user.
alias claudeupdate='claude update'
alias codexupdate='npm install -g @openai/codex@latest'


# --- Disk / file helpers (macOS `df` + `du` dialect) -----------------
# Apple's `df` is BSD-flavored and lacks GNU's -T flag, so this alias
# filters the noisy synthesized /System/Volumes mounts instead of relying
# on column-index sorting.
alias freespace='df -h | grep -vE "^Filesystem|/System/Volumes" | sort -k4 -hr'
alias drives='df -h'
alias disks='drives'

# List the 15 largest entries under the given directory (default: cwd).
# macOS du uses -d DEPTH instead of GNU's --max-depth=DEPTH, and has no
# --time column, so this version is simpler than the ubuntu/.bash_aliases
# counterpart but returns the same actionable output.
treesize() {
  local target="${1:-.}"
  du -ahd 1 "$target" 2>/dev/null | sort -hr | head -n 15
}


# --- Process helpers (BSD ps dialect) --------------------------------
# macOS `ps` does not support the forest-mode "f" flag that the Linux
# version uses for ubuntu's `whowhat`.  Return a flat listing sorted by
# user, hiding the usual daemon accounts so the output is actually about
# real users and their processes.
whowhat() {
  ps -eo user,pid,ppid,%cpu,%mem,stat,time,comm \
    | awk '$1 !~ /^(root|_.*|nobody|daemon)$/' \
    | sort -k1,1
}


# --- Filesystem search ------------------------------------------------
# Grep recursively inside files with a given extension.
#   findstr py "TODO"       -> find TODO in every .py under cwd
#   findstr "md,txt" bug    -> multiple extensions via brace expansion
findstr() {
  # shellcheck disable=SC2145
  eval grep -ri --include=\*."$1" "$2" ./
}


# --- Stack summary ----------------------------------------------------
# "What's this machine running?" one-shot report tailored for macOS /
# Apple Silicon / PyTorch-MPS.  No CUDA/cuDNN/NVIDIA blocks because those
# do not exist on Apple Silicon; see ubuntu/.bash_aliases for the Linux
# version if you are cross-referencing.
version() {
  echo "=== macOS ==="
  sw_vers
  echo

  echo "=== Shell ==="
  if [ -n "${ZSH_VERSION:-}" ]; then
    echo "zsh $ZSH_VERSION ($SHELL)"
  else
    echo "$SHELL"
  fi
  echo

  if command -v python3 >/dev/null 2>&1; then
    local py_exe
    py_exe="$(command -v python3)"
    echo "Python: $("$py_exe" --version 2>&1) ($py_exe)"
    if "$py_exe" -c "import torch" >/dev/null 2>&1; then
      local torch_ver mps_ok
      torch_ver="$("$py_exe" -c 'import torch; print(torch.__version__)')"
      mps_ok="$("$py_exe" -c 'import torch; print(torch.backends.mps.is_available())')"
      echo "PyTorch: $torch_ver (MPS available: $mps_ok)"
    else
      echo "PyTorch: not installed for $py_exe"
    fi
  else
    echo "Python: not found"
  fi

  if command -v brew >/dev/null 2>&1; then
    echo "Homebrew: $(brew --version | head -1) (prefix: $(brew --prefix))"
  fi
}


# --- Safer tmux auto-attach for SSH sessions --------------------------
# Only activates when logged in over SSH and not already inside tmux.
# Local Terminal.app / iTerm2 sessions are left alone because mac users
# typically prefer their native window manager for splits.
if [ -z "${TMUX:-}" ] && [ -n "${SSH_CONNECTION:-}" ] && command -v tmux >/dev/null 2>&1; then
  # Attach to (or create) a per-host session name so reconnects resume
  # where the previous connection dropped.
  tmux attach-session -t "ssh_${HOST:-$(hostname -s)}" 2>/dev/null \
    || tmux new-session -d -s "ssh_${HOST:-$(hostname -s)}" && \
       tmux attach-session -t "ssh_${HOST:-$(hostname -s)}"
fi
