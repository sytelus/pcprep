#!/usr/bin/env bash
# Create or refresh a dedicated Python environment for AI development on macOS.
# This script intentionally avoids installing into the system interpreter.

set -Eeuo pipefail
trap 'on_err "${BASH_COMMAND}" "${LINENO}" "$?"' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mac/common.sh
source "$SCRIPT_DIR/common.sh"

require_macos

AI_ENV_NAME="${AI_ENV_NAME:-ai-dev-mac}"
AI_ENV_DIR="${AI_ENV_DIR:-$HOME/.venvs/$AI_ENV_NAME}"
PYTHON_FORMULA="${PYTHON_FORMULA:-python@3.12}"
INSTALL_JUPYTER_KERNEL="${INSTALL_JUPYTER_KERNEL:-1}"

find_python_bin() {
  local candidate

  if command_exists brew; then
    candidate="$(brew --prefix "$PYTHON_FORMULA" 2>/dev/null || true)"
    if [ -n "$candidate" ] && [ -x "$candidate/bin/python3.12" ]; then
      printf '%s\n' "$candidate/bin/python3.12"
      return 0
    fi
  fi

  if command_exists python3.12; then
    command -v python3.12
    return 0
  fi

  if command_exists python3; then
    command -v python3
    return 0
  fi

  return 1
}

if ! command_exists uv; then
  die "uv is not installed. Run mac/prepare_new_box.sh first so the Python toolchain exists."
fi

PYTHON_BIN="$(find_python_bin || true)"
if [ -z "$PYTHON_BIN" ]; then
  die "No suitable Python interpreter was found. Install $PYTHON_FORMULA first."
fi

log "Using Python interpreter: $PYTHON_BIN"
ensure_dir "$(dirname "$AI_ENV_DIR")"

# Reuse an existing environment when present so reruns remain resumable and do
# not discard working packages or local notebooks bound to this interpreter.
if [ -x "$AI_ENV_DIR/bin/python" ]; then
  log "Reusing existing environment at $AI_ENV_DIR"
else
  uv venv --python "$PYTHON_BIN" "$AI_ENV_DIR"
fi

# Upgrade packaging tooling first so later installs have the best chance of
# succeeding when building a native dependency.
"$AI_ENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel

# Install a short, mainstream AI stack from a pinned requirements file in the repo.
"$AI_ENV_DIR/bin/python" -m pip install --upgrade -r "$SCRIPT_DIR/requirements-ai.txt"

if bool_is_true "$INSTALL_JUPYTER_KERNEL"; then
  # Registering the kernel makes the environment easy to select from Jupyter
  # and VS Code without manually browsing for an interpreter each time.
  "$AI_ENV_DIR/bin/python" -m ipykernel install --user --name "$AI_ENV_NAME" --display-name "Python ($AI_ENV_NAME)"
fi

log "Verifying the PyTorch installation and MPS backend."
"$AI_ENV_DIR/bin/python" <<'PYTHON_CHECK'
import sys
import torch

print(f"Python: {sys.version.split()[0]}")
print(f"PyTorch: {torch.__version__}")
print(f"MPS built: {torch.backends.mps.is_built()}")
print(f"MPS available: {torch.backends.mps.is_available()}")
PYTHON_CHECK

log "AI environment is ready at $AI_ENV_DIR"
log "Activate it with: source \"$AI_ENV_DIR/bin/activate\""
