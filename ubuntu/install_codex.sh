#!/usr/bin/env bash
# Install or update the same user-local Codex binary used by the shell shortcuts.
set -euo pipefail

installer=$(mktemp)
trap 'rm -f -- "$installer"' EXIT
curl -fsSL --retry 3 -o "$installer" https://chatgpt.com/codex/install.sh
CODEX_NON_INTERACTIVE=true CODEX_INSTALL_DIR="$HOME/.local/bin" sh "$installer"
"$HOME/.local/bin/codex" --version

# Older bootstraps installed Codex alongside the active NVM-managed Node.
# Retire that package only after the replacement runs, and only when the
# executable belongs to that specific npm package in the user's NVM tree.
if [[ ${NVM_BIN:-} == "$HOME"/.nvm/versions/node/*/bin && -x "$NVM_BIN/npm" ]]; then
    npm_prefix=${NVM_BIN%/bin}
    if [[ -L "$NVM_BIN/codex" && "$(readlink -f -- "$NVM_BIN/codex")" == "$npm_prefix"/lib/node_modules/@openai/codex/* ]]; then
        "$NVM_BIN/npm" uninstall --global --prefix "$npm_prefix" --ignore-scripts @openai/codex
    fi
fi
