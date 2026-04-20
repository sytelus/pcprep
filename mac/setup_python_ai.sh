#!/usr/bin/env bash
# Install or refresh pcprep's managed "main" Python virtualenv on macOS.  The venv
# is created from Homebrew Python so we avoid Apple's system Python, while also
# staying out of Homebrew's externally-managed site-packages tree.

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
# managed main venv as PyTorch so developers can use one coherent Python stack
# for day-to-day AI work without mutating Homebrew's base interpreter.
# Defaults ON to match the rest of the INSTALL_* opt-outs in prepare_new_box.sh.
INSTALL_MLX="${INSTALL_MLX:-1}"
NO_NET="${NO_NET:-0}"
MAIN_VENV_DIR="$(default_main_venv_dir)"
MAIN_PYTHON_BIN="$MAIN_VENV_DIR/bin/python"

# Fail fast with a clear message instead of letting uv error deep inside a
# resolve/download step. Every install in this script needs network access.
if bool_is_true "$NO_NET"; then
  die "NO_NET=1 is set but this script needs network access for pip installs. Re-run with NO_NET=0 after connecting."
fi

if ! command_exists uv; then
  die "uv is not installed. Run mac/prepare_new_box.sh first so the Python toolchain exists."
fi

PYTHON_BIN="$(find_brew_python_bin "$PYTHON_FORMULA" || true)"
if [ -z "$PYTHON_BIN" ]; then
  die "Homebrew $PYTHON_FORMULA was not found. Install it first via mac/prepare_new_box.sh."
fi

log "Using Homebrew base Python interpreter: $PYTHON_BIN"
log "Managed main Python environment target: $MAIN_VENV_DIR"

ensure_dir "$(dirname "$MAIN_VENV_DIR")"
if [ -x "$MAIN_PYTHON_BIN" ]; then
  log "Refreshing the managed main Python environment."
  "$PYTHON_BIN" -m venv --upgrade "$MAIN_VENV_DIR"
else
  log "Creating the managed main Python environment."
  "$PYTHON_BIN" -m venv "$MAIN_VENV_DIR"
fi

# Install packaging tooling and the AI stack into the managed venv. Packaging
# basics go in first so downstream sdist builds (e.g. sentencepiece) can still
# find pip/setuptools/wheel if they need them during compilation.
uv pip install --python "$MAIN_PYTHON_BIN" --upgrade pip setuptools wheel

# Install the short, mainstream AI stack from the pinned requirements file.
uv pip install --python "$MAIN_PYTHON_BIN" --upgrade -r "$SCRIPT_DIR/requirements-ai.txt"

# Optionally layer Apple's MLX stack on top of the same managed main env.  Kept in
# a separate requirements file so users who want to stay on pure PyTorch can
# set INSTALL_MLX=0 and skip the extra download and disk footprint.
if bool_is_true "$INSTALL_MLX"; then
  if [ "$(uname -m)" = "arm64" ]; then
    log "Installing MLX extras into the managed main Python environment (INSTALL_MLX=1)."
    uv pip install --python "$MAIN_PYTHON_BIN" --upgrade -r "$SCRIPT_DIR/requirements-mlx.txt"
  else
    warn "INSTALL_MLX=1 was requested, but MLX is Apple-Silicon-only. Skipping MLX on $(uname -m)."
  fi
fi

if bool_is_true "$INSTALL_JUPYTER_KERNEL"; then
  # Register the managed main interpreter under a stable, short name so
  # notebooks and editors can select it directly without manual activation.
  KERNEL_NAME="python-main-${PYTHON_MINOR}"
  KERNEL_DISPLAY_NAME="Python ${PYTHON_MINOR} (main)"
  "$MAIN_PYTHON_BIN" -m ipykernel install --user --name "$KERNEL_NAME" --display-name "$KERNEL_DISPLAY_NAME"
fi

log "Verifying the PyTorch installation and MPS backend."
"$MAIN_PYTHON_BIN" <<'PYTHON_CHECK'
import sys
import torch

print(f"Python: {sys.version.split()[0]}")
print(f"PyTorch: {torch.__version__}")
print(f"MPS built: {torch.backends.mps.is_built()}")
print(f"MPS available: {torch.backends.mps.is_available()}")
PYTHON_CHECK

log "Verifying the requested Python package stack."
if bool_is_true "$INSTALL_MLX" && [ "$(uname -m)" = "arm64" ]; then
  "$MAIN_PYTHON_BIN" \
    "$SCRIPT_DIR/check_python_stack.py" \
    "$SCRIPT_DIR/requirements-ai.txt" \
    "$SCRIPT_DIR/requirements-mlx.txt"
else
  "$MAIN_PYTHON_BIN" "$SCRIPT_DIR/check_python_stack.py" "$SCRIPT_DIR/requirements-ai.txt"
fi

log "Python packages are installed into the managed main environment at $MAIN_VENV_DIR"
