#!/usr/bin/env bash
# Verify that the conservative macOS developer setup completed successfully.
# The checks here are deliberately explicit so failures are easy to debug.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mac/common.sh
source "$SCRIPT_DIR/common.sh"

require_macos

AI_ENV_NAME="${AI_ENV_NAME:-ai-dev-mac}"
AI_ENV_DIR="${AI_ENV_DIR:-$HOME/.venvs/$AI_ENV_NAME}"
EXPECT_CLAUDE="${EXPECT_CLAUDE:-1}"
EXPECT_CODEX="${EXPECT_CODEX:-1}"
EXPECT_DOCKER="${EXPECT_DOCKER:-1}"
EXPECT_GUI_APPS="${EXPECT_GUI_APPS:-1}"
EXPECT_AI_ENV="${EXPECT_AI_ENV:-1}"

# Optional install expectations — mirror the INSTALL_* flags in prepare_new_box.sh.
# Default ON so running verify_setup.sh standalone after a normal bootstrap
# validates everything that was installed by default.
EXPECT_OLLAMA="${EXPECT_OLLAMA:-1}"
EXPECT_DEV_FONTS="${EXPECT_DEV_FONTS:-1}"
EXPECT_RUST="${EXPECT_RUST:-1}"
EXPECT_GO="${EXPECT_GO:-1}"
EXPECT_TAILSCALE="${EXPECT_TAILSCALE:-1}"
EXPECT_MLX="${EXPECT_MLX:-1}"
EXPECT_LLAMA_CPP="${EXPECT_LLAMA_CPP:-1}"
EXPECT_EXTRA_CLIS="${EXPECT_EXTRA_CLIS:-1}"
EXPECT_FIREFOX="${EXPECT_FIREFOX:-1}"
EXPECT_CHROME="${EXPECT_CHROME:-1}"

FAILURES=0

pass() {
  printf '%s[PASS] %s\n' "$PCPREP_PREFIX" "$*"
}

fail() {
  printf '%s[FAIL] %s\n' "$PCPREP_PREFIX" "$*" >&2
  FAILURES=$((FAILURES + 1))
}

check_command() {
  local command_name="$1"
  local required_label="$2"

  if command_exists "$command_name"; then
    pass "$required_label is available via '$command_name'."
  else
    fail "$required_label is missing. Expected command: $command_name"
  fi
}

check_path_exists() {
  local target_path="$1"
  local label="$2"

  if [ -e "$target_path" ]; then
    pass "$label exists at $target_path"
  else
    fail "$label is missing at $target_path"
  fi
}

check_brew_formula() {
  # Check that a Homebrew formula is installed.  Kept separate from
  # check_command because some formulas install binaries under non-obvious
  # names (e.g. llama.cpp -> llama-cli) and because "brew list" is the
  # authoritative source of truth regardless of PATH state.
  local formula="$1"
  local label="$2"

  if brew list --formula "$formula" >/dev/null 2>&1; then
    pass "$label is installed (formula: $formula)."
  else
    fail "$label is not installed (expected formula: $formula)."
  fi
}

check_brew_cask() {
  local cask="$1"
  local label="$2"

  if brew list --cask "$cask" >/dev/null 2>&1; then
    pass "$label is installed (cask: $cask)."
  else
    fail "$label is not installed (expected cask: $cask)."
  fi
}

if xcode-select -p >/dev/null 2>&1; then
  pass "Xcode Command Line Tools are installed."
else
  fail "Xcode Command Line Tools are not installed."
fi

check_command brew "Homebrew"
check_command git "Git"
check_command git-lfs "Git LFS"
check_command gh "GitHub CLI"
check_command rg "ripgrep"
check_command fd "fd"
check_command jq "jq"
check_command fzf "fzf"
check_command tmux "tmux"
check_command python3 "Python 3"
check_command python3.12 "Python 3.12"
check_command uv "uv"
check_command node "Node.js"
check_command npm "npm"

if bool_is_true "$EXPECT_CODEX"; then
  check_command codex "Codex CLI"
fi

if bool_is_true "$EXPECT_CLAUDE"; then
  check_command claude "Claude Code"
fi

if bool_is_true "$EXPECT_GUI_APPS"; then
  check_path_exists "/Applications/iTerm.app" "iTerm2"
  check_path_exists "/Applications/Visual Studio Code.app" "Visual Studio Code"
  check_path_exists "/Applications/Rectangle.app" "Rectangle"
  check_command code "VS Code CLI"
fi

if bool_is_true "$EXPECT_DOCKER"; then
  check_path_exists "/Applications/Docker.app" "Docker Desktop"
  if command_exists docker; then
    if docker info >/dev/null 2>&1; then
      pass "Docker CLI can talk to the Docker daemon."
    else
      warn "Docker is installed but the daemon is not reachable yet. Launch Docker Desktop once to finish setup."
    fi
  else
    warn "Docker CLI is not on PATH yet. This usually resolves after Docker Desktop is launched once."
  fi
fi

if bool_is_true "$EXPECT_AI_ENV"; then
  if [ -x "$AI_ENV_DIR/bin/python" ]; then
    pass "AI environment exists at $AI_ENV_DIR"
    if "$AI_ENV_DIR/bin/python" - <<'PYTHON_CHECK'
import torch

print(f"PyTorch: {torch.__version__}")
print(f"MPS available: {torch.backends.mps.is_available()}")
PYTHON_CHECK
    then
      pass "AI environment imports PyTorch successfully."
    else
      fail "AI environment exists but PyTorch verification failed."
    fi
  else
    fail "Expected AI environment is missing at $AI_ENV_DIR"
  fi
fi

# --- Optional install verifications (mirror prepare_new_box.sh INSTALL_* flags) ---

if bool_is_true "$EXPECT_OLLAMA"; then
  # We deliberately install the FORMULA (CLI binary), not the cask, so the
  # check looks for the brew formula rather than an /Applications entry.
  check_brew_formula ollama "Ollama CLI"
fi

if bool_is_true "$EXPECT_LLAMA_CPP"; then
  # The llama.cpp formula installs several binaries (llama-cli, llama-server,
  # llama-quantize, ...).  Checking the formula itself is more reliable than
  # picking one binary name that could change between brew revisions.
  check_brew_formula "llama.cpp" "llama.cpp"
fi

if bool_is_true "$EXPECT_GO"; then
  check_command go "Go toolchain"
fi

if bool_is_true "$EXPECT_TAILSCALE"; then
  # Formula (CLI), not cask — matches maybe_install_tailscale.
  check_brew_formula tailscale "Tailscale CLI"
fi

if bool_is_true "$EXPECT_RUST"; then
  # rustup installs into ~/.cargo/bin, outside brew's prefix, so we check the
  # canonical binary path directly.
  if [ -x "$HOME/.cargo/bin/rustup" ]; then
    pass "Rust toolchain is installed (~/.cargo/bin/rustup)."
  else
    fail "Rust toolchain not found at ~/.cargo/bin/rustup."
  fi
fi

if bool_is_true "$EXPECT_DEV_FONTS"; then
  check_brew_cask font-jetbrains-mono "JetBrains Mono"
  check_brew_cask font-meslo-lg-nerd-font "MesloLG Nerd Font"
  check_brew_cask font-fira-code "Fira Code"
fi

if bool_is_true "$EXPECT_EXTRA_CLIS"; then
  check_brew_formula ncdu "ncdu"
  check_brew_formula sysbench "sysbench"
  check_brew_formula iperf3 "iperf3"
  check_brew_cask appcleaner "AppCleaner"
fi

if bool_is_true "$EXPECT_FIREFOX"; then
  check_brew_cask firefox "Firefox"
fi

if bool_is_true "$EXPECT_CHROME"; then
  check_brew_cask google-chrome "Google Chrome"
fi

if bool_is_true "$EXPECT_MLX"; then
  # MLX is a Python package; verify by importing inside the AI environment.
  if [ -x "$AI_ENV_DIR/bin/python" ]; then
    if "$AI_ENV_DIR/bin/python" -c "import mlx" >/dev/null 2>&1; then
      pass "MLX is importable in the AI environment."
    else
      fail "MLX is expected but not importable in $AI_ENV_DIR."
    fi
  else
    fail "AI environment is missing; cannot verify MLX."
  fi
fi

if [ "$FAILURES" -ne 0 ]; then
  fail "Verification completed with $FAILURES failing check(s)."
  exit 1
fi

pass "Verification completed successfully."
