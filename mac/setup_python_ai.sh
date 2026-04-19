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
NO_NET="${NO_NET:-0}"

# Fail fast with a clear message instead of letting uv error deep inside a
# resolve/download step. Every install in this script needs network access.
if bool_is_true "$NO_NET"; then
  die "NO_NET=1 is set but this script needs network access for pip installs. Re-run with NO_NET=0 after connecting."
fi

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

# Install packaging tooling and the AI stack with "uv pip --python".
# Two things to note:
#   1. "uv venv" does not seed pip/setuptools/wheel into the venv, so a call
#      like "$VENV/bin/python -m pip install" would fail with "No module named
#      pip" on a freshly created environment.
#   2. "uv pip install --python <interp>" installs directly into the target
#      interpreter's site-packages using uv's resolver and does not require
#      pip to already be present in the venv.
# Packaging basics go in first so downstream sdist builds (e.g. sentencepiece)
# can still find pip/setuptools/wheel if they need them during compilation.
uv pip install --python "$AI_ENV_DIR/bin/python" --upgrade pip setuptools wheel

# Install the short, mainstream AI stack from the pinned requirements file.
uv pip install --python "$AI_ENV_DIR/bin/python" --upgrade -r "$SCRIPT_DIR/requirements-ai.txt"

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
