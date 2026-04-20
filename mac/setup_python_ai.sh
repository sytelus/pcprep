#!/usr/bin/env bash
# Install or refresh the AI Python package set directly into the Homebrew
# Python interpreter on macOS.  This intentionally avoids Apple's system
# Python while also avoiding a separate project-specific virtualenv.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mac/common.sh
source "$SCRIPT_DIR/common.sh"

# Install the ERR trap *after* sourcing common.sh so on_err is always defined.
trap 'on_err "${BASH_COMMAND}" "${LINENO}" "$?"' ERR

require_macos

PYTHON_FORMULA="${PYTHON_FORMULA:-python@3.12}"
PYTHON_MINOR="${PYTHON_FORMULA#python@}"
INSTALL_JUPYTER_KERNEL="${INSTALL_JUPYTER_KERNEL:-1}"
# Apple's MLX framework for native Metal inference.  Installed into the same
# Homebrew Python interpreter as PyTorch so developers can use one default
# Python toolchain for day-to-day AI work.
# Defaults ON to match the rest of the INSTALL_* opt-outs in prepare_new_box.sh.
INSTALL_MLX="${INSTALL_MLX:-1}"
NO_NET="${NO_NET:-0}"

# Fail fast with a clear message instead of letting uv error deep inside a
# resolve/download step. Every install in this script needs network access.
if bool_is_true "$NO_NET"; then
  die "NO_NET=1 is set but this script needs network access for pip installs. Re-run with NO_NET=0 after connecting."
fi

find_python_bin() {
  local prefix

  if ! command_exists brew; then
    return 1
  fi

  prefix="$(brew --prefix "$PYTHON_FORMULA" 2>/dev/null || true)"
  if [ -n "$prefix" ] && [ -x "$prefix/bin/python${PYTHON_MINOR}" ]; then
    printf '%s\n' "$prefix/bin/python${PYTHON_MINOR}"
    return 0
  fi

  return 1
}

if ! command_exists uv; then
  die "uv is not installed. Run mac/prepare_new_box.sh first so the Python toolchain exists."
fi

PYTHON_BIN="$(find_python_bin || true)"
if [ -z "$PYTHON_BIN" ]; then
  die "Homebrew $PYTHON_FORMULA was not found. Install it first via mac/prepare_new_box.sh."
fi

log "Using Python interpreter: $PYTHON_BIN"

# Install packaging tooling and the AI stack with "uv pip --python" directly
# into the selected Homebrew Python interpreter.
# Packaging basics go in first so downstream sdist builds (e.g. sentencepiece)
# can still find pip/setuptools/wheel if they need them during compilation.
uv pip install --python "$PYTHON_BIN" --upgrade pip setuptools wheel

# Install the short, mainstream AI stack from the pinned requirements file.
uv pip install --python "$PYTHON_BIN" --upgrade -r "$SCRIPT_DIR/requirements-ai.txt"

# Optionally layer Apple's MLX stack on top of the same interpreter.  Kept in a
# separate requirements file so users who want to stay on pure PyTorch can set
# INSTALL_MLX=0 and skip the extra download and disk footprint.
if bool_is_true "$INSTALL_MLX"; then
  log "Installing MLX extras into the Homebrew Python interpreter (INSTALL_MLX=1)."
  uv pip install --python "$PYTHON_BIN" --upgrade -r "$SCRIPT_DIR/requirements-mlx.txt"
fi

if bool_is_true "$INSTALL_JUPYTER_KERNEL"; then
  # Register the Homebrew interpreter under a neutral, version-based name so
  # notebooks and editors can select it easily without any "AI env" branding.
  KERNEL_NAME="python-homebrew-${PYTHON_MINOR}"
  KERNEL_DISPLAY_NAME="Python ${PYTHON_MINOR} (Homebrew)"
  "$PYTHON_BIN" -m ipykernel install --user --name "$KERNEL_NAME" --display-name "$KERNEL_DISPLAY_NAME"
fi

log "Verifying the PyTorch installation and MPS backend."
"$PYTHON_BIN" <<'PYTHON_CHECK'
import sys
import torch

print(f"Python: {sys.version.split()[0]}")
print(f"PyTorch: {torch.__version__}")
print(f"MPS built: {torch.backends.mps.is_built()}")
print(f"MPS available: {torch.backends.mps.is_available()}")
PYTHON_CHECK

log "AI Python packages are installed into the Homebrew interpreter at $PYTHON_BIN"
