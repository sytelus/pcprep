#!/usr/bin/env bash
# Verify that the macOS developer setup completed successfully.
#
# Design:
# - No `set -e`: we accumulate a FAILURES counter across independent checks
#   and exit non-zero only at the very end.  That way one missing tool does
#   not hide the rest of the report from the user.
# - Coverage is layered:
#     1. Hand-picked command checks for a small, high-signal set of tools
#        (brew, git, uv, node, npm, python).  These must be on PATH for the
#        rest of the environment to work.
#     2. `brew bundle check` covers the full core CLI Brewfile.  GUI apps are
#        checked explicitly because prepare_new_box.sh may adopt a preexisting
#        app bundle instead of insisting Homebrew owns it.
#     3. Optional EXPECT_* flags mirror the INSTALL_* flags in
#        prepare_new_box.sh so verification can be narrowed the same way the
#        install was narrowed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mac/common.sh
source "$SCRIPT_DIR/common.sh"

require_macos

# Python formula we expect to find on PATH.  Derived from the same env var
# setup_python_ai.sh uses so the two scripts always agree on which minor
# version to validate.  "python@3.12" -> "3.12".
PYTHON_FORMULA="${PYTHON_FORMULA:-python@3.12}"
PYTHON_MINOR="${PYTHON_FORMULA#python@}"

EXPECT_CLAUDE="${EXPECT_CLAUDE:-1}"
EXPECT_CLAUDE_APP="${EXPECT_CLAUDE_APP:-1}"
EXPECT_CODEX="${EXPECT_CODEX:-1}"
EXPECT_CODEX_APP="${EXPECT_CODEX_APP:-1}"
EXPECT_DOCKER="${EXPECT_DOCKER:-1}"
EXPECT_GITHUB_COPILOT_CLI="${EXPECT_GITHUB_COPILOT_CLI:-1}"
EXPECT_GUI_APPS="${EXPECT_GUI_APPS:-1}"
EXPECT_AI_ENV="${EXPECT_AI_ENV:-1}"
EXPECT_MINICONDA="${EXPECT_MINICONDA:-1}"
EXPECT_DOTFILES="${EXPECT_DOTFILES:-1}"
EXPECT_POWERLEVEL10K="${EXPECT_POWERLEVEL10K:-0}"

# Optional install expectations — mirror INSTALL_* in prepare_new_box.sh.
# Default ON so running verify_setup.sh standalone after a normal bootstrap
# validates everything that was installed by default.
EXPECT_OLLAMA="${EXPECT_OLLAMA:-1}"
EXPECT_DEV_FONTS="${EXPECT_DEV_FONTS:-1}"
EXPECT_RUST="${EXPECT_RUST:-1}"
EXPECT_GO="${EXPECT_GO:-1}"
EXPECT_TAILSCALE="${EXPECT_TAILSCALE:-1}"
EXPECT_LLAMA_CPP="${EXPECT_LLAMA_CPP:-1}"
EXPECT_EXTRA_CLIS="${EXPECT_EXTRA_CLIS:-1}"
EXPECT_FIREFOX="${EXPECT_FIREFOX:-1}"
EXPECT_CHROME="${EXPECT_CHROME:-1}"
MINICONDA_DIR="${MINICONDA_DIR:-$HOME/miniconda3}"

if [ -n "${EXPECT_MLX+x}" ]; then
  EXPECT_MLX="${EXPECT_MLX:-0}"
elif [ "$(uname -m)" = "arm64" ]; then
  EXPECT_MLX=1
else
  EXPECT_MLX=0
fi

FAILURES=0

# --- Reporting helpers ------------------------------------------------------

# Print a green-flavored success line for a check.
pass() {
  printf '%s[PASS] %s\n' "$PCPREP_PREFIX" "$*"
}

# Print a failure line to stderr and bump the global FAILURES counter.
fail() {
  printf '%s[FAIL] %s\n' "$PCPREP_PREFIX" "$*" >&2
  FAILURES=$((FAILURES + 1))
}

# --- Individual-check helpers ----------------------------------------------

# Assert that a command is resolvable on the current PATH.
check_command() {
  local command_name="$1"
  local required_label="$2"

  if command_exists "$command_name"; then
    pass "$required_label is available via '$command_name'."
  else
    fail "$required_label is missing. Expected command: $command_name"
  fi
}

check_azure_cli_extension_setup() {
  local azure_config_dir
  local azure_extension_dir
  local azure_config_file

  azure_config_dir="${AZURE_CONFIG_DIR:-$HOME/.azure}"
  azure_extension_dir="${AZURE_EXTENSION_DIR:-$azure_config_dir/cliextensions}"
  azure_config_file="$azure_config_dir/config"

  check_path_exists "$azure_extension_dir" "Azure CLI extensions directory"

  if [ -w "$azure_extension_dir" ]; then
    pass "Azure CLI extensions directory is user-writable at $azure_extension_dir"
  else
    fail "Azure CLI extensions directory is not writable at $azure_extension_dir"
  fi

  if [ -f "$azure_config_file" ] && awk '
    /^\[/ { section=$0; next }
    section == "[extension]" && $0 ~ /^[[:space:]]*use_dynamic_install[[:space:]]*=[[:space:]]*yes_without_prompt[[:space:]]*$/ { found=1 }
    END { exit(found ? 0 : 1) }
  ' "$azure_config_file"; then
    pass "Azure CLI dynamic extension install is set to yes_without_prompt."
  else
    fail "Azure CLI dynamic extension install is not configured to yes_without_prompt."
  fi
}

check_git_global_value() {
  local key="$1"
  local expected_value="$2"
  local label="$3"
  local actual_values

  if ! command_exists git; then
    fail "$label not verified (git command missing)."
    return
  fi

  actual_values="$(git config --global --get-all "$key" 2>/dev/null || true)"
  if printf '%s\n' "$actual_values" | grep -Fxq "$expected_value"; then
    pass "$label"
  else
    fail "$label"
  fi
}

# Compile and run tiny C and C++ programs through Apple's toolchain so we
# validate real native-build functionality, not just the presence of CLT files.
check_c_cpp_toolchain() {
  local temp_dir
  local c_src
  local cpp_src
  local c_bin
  local cpp_bin

  if ! xcrun --find clang >/dev/null 2>&1; then
    fail "Apple Clang is not available via xcrun."
    return
  fi

  if ! xcrun --find clang++ >/dev/null 2>&1; then
    fail "Apple Clang++ is not available via xcrun."
    return
  fi

  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pcprep-mac-cxx.XXXXXX")"
  c_src="$temp_dir/hello.c"
  cpp_src="$temp_dir/hello.cpp"
  c_bin="$temp_dir/hello-c"
  cpp_bin="$temp_dir/hello-cpp"

  cat > "$c_src" <<'EOF'
#include <stdio.h>

int main(void) {
  puts("pcprep-c-ok");
  return 0;
}
EOF

  cat > "$cpp_src" <<'EOF'
#include <iostream>

int main() {
  std::cout << "pcprep-cpp-ok\n";
  return 0;
}
EOF

  if xcrun clang "$c_src" -o "$c_bin" >/dev/null 2>&1 && "$c_bin" >/dev/null 2>&1; then
    pass "C toolchain compiles and runs a simple program."
  else
    fail "C toolchain smoke test failed."
  fi

  if xcrun clang++ -std=c++17 "$cpp_src" -o "$cpp_bin" >/dev/null 2>&1 && "$cpp_bin" >/dev/null 2>&1; then
    pass "C++ toolchain compiles and runs a simple program."
  else
    fail "C++ toolchain smoke test failed."
  fi

  rm -rf "$temp_dir"
}

check_python_import_stack() {
  local python_bin="$1"
  local check_label="$2"

  if "$python_bin" "$SCRIPT_DIR/check_python_stack.py"
  then
    pass "$check_label"
  else
    fail "$check_label"
  fi
}

# Assert that a filesystem path (file, directory, or app bundle) exists.
check_path_exists() {
  local target_path="$1"
  local label="$2"

  if [ -e "$target_path" ]; then
    pass "$label exists at $target_path"
  else
    fail "$label is missing at $target_path"
  fi
}

# Assert that a Homebrew formula is installed.  Prefer this over check_command
# when a formula's binary has a non-obvious name (e.g. llama.cpp installs
# `llama-cli`), and for side-by-side formulas like `bash` where check_command
# would find Apple's /bin/bash before reaching brew's.
check_brew_formula() {
  local formula="$1"
  local label="$2"

  if ! command_exists brew; then
    fail "$label not verified (brew command missing)."
    return
  fi
  if brew list --formula "$formula" >/dev/null 2>&1; then
    pass "$label is installed (formula: $formula)."
  else
    fail "$label is not installed (expected formula: $formula)."
  fi
}

# Assert that a Homebrew cask is installed.
check_brew_cask() {
  local cask="$1"
  local label="$2"

  if ! command_exists brew; then
    fail "$label not verified (brew command missing)."
    return
  fi
  if brew list --cask "$cask" >/dev/null 2>&1; then
    pass "$label is installed (cask: $cask)."
  else
    fail "$label is not installed (expected cask: $cask)."
  fi
}

check_brew_cask_or_app_bundle() {
  local cask="$1"
  local label="$2"
  local app_path

  shift 2

  if ! command_exists brew; then
    fail "$label not verified (brew command missing)."
    return
  fi

  if brew list --cask "$cask" >/dev/null 2>&1; then
    pass "$label is installed (cask: $cask)."
    return
  fi

  for app_path in "$@"; do
    if [ -d "$app_path" ]; then
      pass "$label exists at $app_path."
      return
    fi
  done

  fail "$label is not installed (expected cask: $cask or app bundle in Applications)."
}

# Assert that every item in a Brewfile is installed.  Uses `brew bundle check`
# which returns non-zero if anything is missing.  Much cleaner than duplicating
# the Brewfile contents as individual check_command calls.
check_brewfile() {
  local bundle_file="$1"
  local label="$2"

  if ! command_exists brew; then
    fail "$label not verified (brew command missing)."
    return
  fi
  if [ ! -f "$bundle_file" ]; then
    fail "$label manifest missing: $bundle_file"
    return
  fi
  if brew bundle check --file="$bundle_file" --no-upgrade >/dev/null 2>&1; then
    pass "$label are all installed (per $(basename "$bundle_file"))."
  else
    fail "$label are incomplete. Run 'brew bundle --file=$bundle_file' to install missing items."
  fi
}

# --- Foundation checks -----------------------------------------------------

# Xcode Command Line Tools are a hard prerequisite for Homebrew itself.
if xcode-select -p >/dev/null 2>&1; then
  pass "Xcode Command Line Tools are installed."
else
  fail "Xcode Command Line Tools are not installed."
fi

# Small, high-signal set of tools every downstream step depends on.  Broader
# coverage comes from check_brewfile below so we do not duplicate the Brewfile
# contents here.
check_command brew "Homebrew"
check_command git  "Git"
check_git_global_value \
  'url.ssh://git@github.com/.insteadOf' \
  'https://github.com/' \
  "GitHub HTTPS remotes are rewritten to SSH."
check_command uv   "uv"
check_command node "Node.js"
check_command npm  "npm"
check_command az "Azure CLI"
check_command azcopy "AzCopy"
check_azure_cli_extension_setup
check_command tmux "tmux"
check_command zellij "zellij"
check_command pv "pv"
check_command micro "micro"
check_command fdupes "fdupes"
check_command xz "xz"
check_brew_formula screen "GNU Screen"
check_command cmake "CMake"
check_command ninja "Ninja"
check_command pkg-config "pkg-config"
check_command "python${PYTHON_MINOR}" "Python ${PYTHON_MINOR} (from ${PYTHON_FORMULA})"
check_c_cpp_toolchain

PYTHON_BIN="$(find_brew_python_bin "$PYTHON_FORMULA" || true)"

# Validate the full CLI manifest in one shot.  Any missing formula surfaces
# a single failure line here with the command to re-install.
check_brewfile "$SCRIPT_DIR/Brewfile.core" "Brewfile.core formulas"

# --- Optional / conditional checks -----------------------------------------

if bool_is_true "$EXPECT_CODEX"; then
  check_command codex "Codex CLI"
fi

if bool_is_true "$EXPECT_CLAUDE"; then
  check_command claude "Claude Code"
fi

if bool_is_true "$EXPECT_GITHUB_COPILOT_CLI"; then
  check_brew_cask copilot-cli "GitHub Copilot CLI"
  check_command copilot "GitHub Copilot CLI command"
fi

if bool_is_true "$EXPECT_CODEX_APP"; then
  check_brew_cask_or_app_bundle \
    codex-app \
    "Codex app" \
    "/Applications/Codex.app" \
    "$HOME/Applications/Codex.app"
fi

if bool_is_true "$EXPECT_CLAUDE_APP"; then
  check_brew_cask_or_app_bundle \
    claude \
    "Claude app" \
    "/Applications/Claude.app" \
    "$HOME/Applications/Claude.app"
fi

if bool_is_true "$EXPECT_GUI_APPS"; then
  check_brew_cask_or_app_bundle \
    iterm2 \
    "iTerm2" \
    "/Applications/iTerm.app" \
    "$HOME/Applications/iTerm.app"
  check_brew_cask_or_app_bundle \
    visual-studio-code \
    "Visual Studio Code" \
    "/Applications/Visual Studio Code.app" \
    "$HOME/Applications/Visual Studio Code.app"
  check_brew_cask_or_app_bundle \
    rectangle \
    "Rectangle" \
    "/Applications/Rectangle.app" \
    "$HOME/Applications/Rectangle.app"
  # Code CLI is a user-local symlink created by maybe_link_vscode_cli, not a
  # cask file, so check it explicitly.
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
  if [ -n "$PYTHON_BIN" ] && [ -x "$PYTHON_BIN" ]; then
    pass "Homebrew Python interpreter exists at $PYTHON_BIN"
    # Capture interpreter output so the PASS / FAIL status line lands near
    # its own heading rather than being visually separated by Python stdout.
    if "$PYTHON_BIN" - <<'PYTHON_CHECK'
import torch

print(f"PyTorch: {torch.__version__}")
print(f"MPS available: {torch.backends.mps.is_available()}")
PYTHON_CHECK
    then
      pass "Homebrew Python imports PyTorch successfully."
    else
      fail "Homebrew Python exists but PyTorch verification failed."
    fi

    check_python_import_stack \
      "$PYTHON_BIN" \
      "Homebrew Python imports the requested AI and notebook packages successfully."
  else
    fail "Expected Homebrew Python interpreter is missing for AI package verification."
  fi
fi

if bool_is_true "$EXPECT_MINICONDA"; then
  if [ -x "$MINICONDA_DIR/bin/conda" ]; then
    pass "Miniconda is installed at $MINICONDA_DIR."
    if "$MINICONDA_DIR/bin/conda" config --show auto_activate_base >/dev/null 2>&1; then
      if "$MINICONDA_DIR/bin/conda" config --show auto_activate_base 2>/dev/null | grep -Eq 'auto_activate_base: false'; then
        pass "Miniconda auto_activate_base is disabled."
      else
        fail "Miniconda is installed but auto_activate_base is not disabled."
      fi
    else
      fail "Miniconda is installed but conda config could not be queried."
    fi
  else
    fail "Expected Miniconda install is missing at $MINICONDA_DIR."
  fi
fi

if bool_is_true "$EXPECT_OLLAMA"; then
  # Installed as FORMULA (no auto-start daemon), not the cask.
  check_brew_formula ollama "Ollama CLI"
fi

if bool_is_true "$EXPECT_LLAMA_CPP"; then
  # The formula exposes several binaries (llama-cli, llama-server, ...);
  # checking the formula itself is more stable than picking one binary name.
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
  # canonical binary path directly instead of via brew.
  if [ -x "$HOME/.cargo/bin/rustup" ]; then
    pass "Rust toolchain is installed (~/.cargo/bin/rustup)."
  else
    fail "Rust toolchain not found at ~/.cargo/bin/rustup."
  fi
fi

if bool_is_true "$EXPECT_DEV_FONTS"; then
  check_brew_cask font-jetbrains-mono     "JetBrains Mono"
  check_brew_cask font-meslo-lg-nerd-font "MesloLG Nerd Font"
  check_brew_cask font-fira-code          "Fira Code"
fi

if bool_is_true "$EXPECT_DOTFILES"; then
  check_path_exists "$HOME/.config/pcprep/macos-shellenv.sh" "Managed shellenv fragment"
  check_path_exists "$HOME/.config/pcprep/pcprep-shell.zsh" "Managed zsh shell fragment"
  check_path_exists "$HOME/.config/pcprep/pcprep-shell.bash" "Managed bash shell fragment"
  check_path_exists "$HOME/.config/pcprep/pcprep-shell.common.sh" "Managed shared shell fragment"
  check_path_exists "$HOME/.config/pcprep/pcprep-aliases.sh" "Managed alias layer"
fi

if bool_is_true "$EXPECT_POWERLEVEL10K"; then
  check_brew_formula powerlevel10k "Powerlevel10k prompt"
  check_path_exists "$HOME/.config/pcprep/pcprep-p10k.zsh" "Managed Powerlevel10k config"
fi

if bool_is_true "$EXPECT_EXTRA_CLIS"; then
  check_command tlrc "tlrc"
  check_brew_formula ncdu "ncdu"
  check_brew_formula moreutils "moreutils"
  check_command rename "rename"
  check_command entr "entr"
  check_brew_formula rsync "rsync"
  check_brew_formula sysbench "sysbench"
  check_brew_formula iperf3 "iperf3"
  check_command meson "Meson"
  check_command autoconf "autoconf"
  check_command automake "automake"
  check_brew_formula libtool "GNU libtool"
  check_command ccache "ccache"
  check_command autossh "autossh"
  check_command mtr "mtr"
  check_command nmap "nmap"
  check_brew_formula kubernetes-cli "kubectl"
  check_command rclone "rclone"
  check_command zstd "zstd"
  check_command pigz "pigz"
  check_command pbzip2 "pbzip2"
  check_brew_formula sevenzip "7-Zip"
  check_command unar "unar"
  check_command ffmpeg "FFmpeg"
  check_brew_cask_or_app_bundle \
    appcleaner \
    "AppCleaner" \
    "/Applications/AppCleaner.app" \
    "$HOME/Applications/AppCleaner.app"
fi

if bool_is_true "$EXPECT_FIREFOX"; then
  check_brew_cask_or_app_bundle \
    firefox \
    "Firefox" \
    "/Applications/Firefox.app" \
    "$HOME/Applications/Firefox.app"
fi

if bool_is_true "$EXPECT_CHROME"; then
  check_brew_cask_or_app_bundle \
    google-chrome \
    "Google Chrome" \
    "/Applications/Google Chrome.app" \
    "$HOME/Applications/Google Chrome.app"
fi

if bool_is_true "$EXPECT_MLX"; then
  # MLX is a Python package; verify by importing inside the Homebrew Python
  # interpreter that setup_python_ai.sh installs into.
  if [ -n "$PYTHON_BIN" ] && [ -x "$PYTHON_BIN" ]; then
    if "$PYTHON_BIN" -c "import mlx" >/dev/null 2>&1; then
      pass "MLX is importable in the Homebrew Python interpreter."
    else
      fail "MLX is expected but not importable in $PYTHON_BIN."
    fi
  else
    fail "Homebrew Python interpreter is missing; cannot verify MLX."
  fi
fi

# --- Summary ---------------------------------------------------------------

if [ "$FAILURES" -ne 0 ]; then
  fail "Verification completed with $FAILURES failing check(s)."
  exit 1
fi

pass "Verification completed successfully."
