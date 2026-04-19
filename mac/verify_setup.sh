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

if [ "$FAILURES" -ne 0 ]; then
  fail "Verification completed with $FAILURES failing check(s)."
  exit 1
fi

pass "Verification completed successfully."
