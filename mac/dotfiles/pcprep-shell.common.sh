# Managed by pcprep — sourced from both bash and zsh shell fragments.
# This file is REWRITTEN on every run of apply_dotfiles.sh.  Do not edit by
# hand; instead, edit mac/dotfiles/pcprep-shell.common.sh in the repo.

# --- General environment ----------------------------------------------
export PYTHONHASHSEED=0

# --- AI data / cache layout -------------------------------------------
export DATA_ROOT="$HOME/data"
export CACHE_ROOT="$HOME/misc_caches"
export MODELS_ROOT="$HOME/models"
export OUT_DIR="$HOME/out_dir"

export HF_HOME="$CACHE_ROOT/hf_home"
export HF_DATASETS_CACHE="$CACHE_ROOT/datasets"
export TIKTOKEN_CACHE_DIR="$CACHE_ROOT/tiktoken_cache"
export WANDB_CACHE_DIR="$CACHE_ROOT/wandb_cache"
export OLLAMA_MODELS="$MODELS_ROOT/ollama"

for _pcprep_dir in \
  "$DATA_ROOT" "$CACHE_ROOT" "$MODELS_ROOT" "$OUT_DIR" \
  "$HF_HOME" "$HF_DATASETS_CACHE" "$TIKTOKEN_CACHE_DIR" \
  "$WANDB_CACHE_DIR" "$OLLAMA_MODELS"; do
  [ -d "$_pcprep_dir" ] || mkdir -p "$_pcprep_dir"
done
unset _pcprep_dir


# --- Shared aliases / helpers -----------------------------------------
# These aliases come from ubuntu/.bash_aliases and are guarded there where
# Linux-only behavior would be noisy or wrong on macOS.
if [ -f "$HOME/.config/pcprep/pcprep-aliases.sh" ]; then
  . "$HOME/.config/pcprep/pcprep-aliases.sh"
fi


# --- Safer tmux auto-attach for SSH sessions --------------------------
if [ -z "${TMUX:-}" ] && [ -n "${SSH_CONNECTION:-}" ] && command -v tmux >/dev/null 2>&1; then
  _pcprep_tmux_session="ssh_${HOST:-$(hostname -s)}"
  tmux attach-session -t "$_pcprep_tmux_session" 2>/dev/null || {
    tmux new-session -d -s "$_pcprep_tmux_session" &&
      tmux attach-session -t "$_pcprep_tmux_session"
  }
  unset _pcprep_tmux_session
fi
