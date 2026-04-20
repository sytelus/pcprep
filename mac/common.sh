#!/usr/bin/env bash
# Shared helper functions for the macOS bootstrap scripts.
#
# This file is sourced (never executed directly) by:
#   - prepare_new_box.sh
#   - setup_python_ai.sh
#   - apply_defaults.sh
#   - revert_defaults.sh
#   - verify_setup.sh
#
# Compatibility: kept Bash 3.2-safe because a fresh macOS install still ships
# Apple's ancient Bash 3.2 at /bin/bash, and that's the shell that runs the
# bootstrap until Homebrew and our newer Bash 5.x are installed.  Avoid
# Bash 4+ features like associative arrays, `${var,,}`, `readarray`.

set -u

PCPREP_PREFIX="[pcprep-mac]"

# Deferred user-message queue: populated by append_next_step from any sourcing
# script and printed at the end of the run by print_next_steps.  Initializing
# here lets scripts that source common.sh without first declaring the array
# still call append_next_step without tripping `set -u`.  The "+x" form leaves
# any pre-populated array from the caller intact.
if [ -z "${NEXT_STEPS+x}" ]; then
  NEXT_STEPS=()
fi

# PID of the background helper that periodically refreshes the cached sudo
# timestamp during a long-running bootstrap. Empty means no helper is active.
SUDO_KEEPALIVE_PID="${SUDO_KEEPALIVE_PID:-}"

# Print an informational message to stdout with the pcprep prefix.
log() {
  printf '%s[INFO] %s\n' "$PCPREP_PREFIX" "$*"
}

# Print a warning to stderr with the pcprep prefix.  Non-fatal.
warn() {
  printf '%s[WARN] %s\n' "$PCPREP_PREFIX" "$*" >&2
}

# Print an error to stderr and terminate the script with exit status 1.
die() {
  printf '%s[ERROR] %s\n' "$PCPREP_PREFIX" "$*" >&2
  exit 1
}

# ERR-trap handler.  Installed by each top-level script AFTER it sources this
# file, so on_err is always defined when the trap fires.  Prints the failing
# command, the line number, and the captured exit code so post-mortem debug
# does not require re-running with xtrace.
on_err() {
  local failed_command="$1"
  local failed_line="$2"
  local failed_status="$3"

  printf '%s[ERROR] Command failed with exit code %s at line %s: %s\n' \
    "$PCPREP_PREFIX" "$failed_status" "$failed_line" "$failed_command" >&2
  exit "$failed_status"
}

# Return 0 if a command is available on PATH, 1 otherwise.
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Flexible boolean parser.  Treats 1/y/Y/yes/YES/true/TRUE/on/ON as truthy,
# anything else (including empty/unset via "${1:-0}") as falsy.  Returns 0
# for truthy, 1 for falsy so it composes naturally with `if bool_is_true …`.
bool_is_true() {
  case "${1:-0}" in
    1|y|Y|yes|YES|true|TRUE|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Return 0 when both stdin and stdout are attached to a terminal (i.e. the
# user can actually answer a `read` prompt).  Used to decide whether to fall
# back to interactive prompts versus silently skipping optional input.
is_interactive() {
  [ -t 0 ] && [ -t 1 ]
}

# Abort with a clear message unless running on macOS.  Called by every
# top-level script before it touches anything platform-specific.
require_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    die "These scripts only support macOS. Detected: $(uname -s)"
  fi
}

# Idempotent `mkdir -p`.
ensure_dir() {
  mkdir -p "$1"
}

# Ensure a file exists, creating any missing parent directories along the way.
# Leaves the file contents unchanged when it already exists.
ensure_file() {
  local target_file="$1"
  ensure_dir "$(dirname "$target_file")"
  touch "$target_file"
}

# Append a line to a file only if no identical line is already present
# (fixed-string, whole-line match via `grep -Fqx`).  Safe to rerun.
ensure_line_in_file() {
  local target_file="$1"
  local expected_line="$2"

  ensure_file "$target_file"

  if ! grep -Fqx "$expected_line" "$target_file"; then
    printf '%s\n' "$expected_line" >> "$target_file"
  fi
}

# Maintain a fenced "managed block" inside a file.  On each call we strip any
# existing block bounded by block_start/block_end and append a fresh copy of
# block_content between those markers.  This gives us idempotent updates to
# generated config without ever owning the user's whole file.
#   $1: target file
#   $2: opening marker line (e.g. "# >>> pcprep macos shellenv >>>")
#   $3: closing marker line
#   $4: block body (may be multi-line; no markers needed, we add them)
upsert_managed_block() {
  local target_file="$1"
  local block_start="$2"
  local block_end="$3"
  local block_content="$4"
  local temp_file

  ensure_file "$target_file"
  temp_file="$(mktemp "${TMPDIR:-/tmp}/pcprep-mac.XXXXXX")"

  # Pass 1: write every line of the existing file EXCEPT the currently
  # managed block (if any) into a temp file.
  awk -v start="$block_start" -v end="$block_end" '
    $0 == start { skip = 1; next }
    $0 == end   { skip = 0; next }
    skip != 1   { print }
  ' "$target_file" > "$temp_file"

  # Pass 2: rewrite the target as [existing content, blank line, fresh block].
  {
    cat "$temp_file"
    if [ -s "$temp_file" ]; then
      printf '\n'
    fi
    printf '%s\n' "$block_start"
    printf '%s\n' "$block_content"
    printf '%s\n' "$block_end"
  } > "$target_file"

  rm -f "$temp_file"
}

# Return 0 if the machine can reach the public internet.  Prefers a lightweight
# HTTPS HEAD probe because many corporate/captive networks block ICMP; falls
# back to Apple's captive-portal detection endpoint (always reachable from a
# connected Mac).  Requires curl, which the CLT install on macOS provides.
has_internet() {
  if command_exists curl; then
    curl -fsSI --max-time 5 https://clients3.google.com/generate_204 >/dev/null 2>&1 && return 0
    curl -fsSI --max-time 5 https://www.apple.com                   >/dev/null 2>&1 && return 0
  fi
  return 1
}

# Run a command with elevated privileges.  Uses sudo only when not already
# root; preserves exit status transparently.  The command and its args are
# forwarded as separate arguments (no shell quoting surprises).
run_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Establish a cached sudo session at the start of a script so later privileged
# steps do not each prompt for a password.  Returns 0 if the session is good
# (or we are already root), 1 if sudo is missing or the user declined to
# authenticate.  Callers should treat a non-zero return as "skip privileged
# steps" rather than as a hard error.
ensure_sudo_session() {
  if [ "$(id -u)" -eq 0 ]; then
    return 0
  fi

  if ! command_exists sudo; then
    warn "sudo is not available. Privileged steps will be skipped."
    return 1
  fi

  if ! sudo -v; then
    warn "Unable to obtain sudo privileges. Privileged steps will be skipped."
    return 1
  fi

  return 0
}

# Keep the cached sudo timestamp alive during long-running setup so the user is
# not re-prompted midway through package installs or later privileged steps.
# Requires ensure_sudo_session to have succeeded first.
start_sudo_keepalive() {
  if [ "$(id -u)" -eq 0 ]; then
    return 0
  fi

  if [ -n "${SUDO_KEEPALIVE_PID:-}" ] && kill -0 "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1; then
    return 0
  fi

  if ! command_exists sudo; then
    return 1
  fi

  (
    while true; do
      sudo -n true >/dev/null 2>&1 || exit 0
      sleep 60
    done
  ) &
  SUDO_KEEPALIVE_PID="$!"
  return 0
}

# Stop the background sudo keepalive helper if one is running.
stop_sudo_keepalive() {
  if [ -n "${SUDO_KEEPALIVE_PID:-}" ] && kill -0 "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1; then
    kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
    wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
  SUDO_KEEPALIVE_PID=""
}

# Return the conventional Homebrew prefix for the current CPU architecture.
# Apple Silicon (arm64) uses /opt/homebrew; Intel (x86_64) uses /usr/local.
# Unknown architectures fall through to the Apple Silicon path because any
# future Mac hardware will almost certainly be ARM-based.
brew_prefix_guess() {
  case "$(uname -m)" in
    arm64)
      printf '%s\n' "/opt/homebrew"
      ;;
    x86_64)
      printf '%s\n' "/usr/local"
      ;;
    *)
      printf '%s\n' "/opt/homebrew"
      ;;
  esac
}

# Queue a user-visible reminder to be printed at the end of the run.  Used for
# actions that cannot be automated (GUI approvals, post-install sign-ins, etc).
append_next_step() {
  NEXT_STEPS+=("$1")
}

# Print the queued NEXT_STEPS messages as a numbered list.  No-op when the
# queue is empty.  Called once by prepare_new_box.sh at the end of main().
print_next_steps() {
  local step
  local index=1

  if [ "${#NEXT_STEPS[@]}" -eq 0 ]; then
    return 0
  fi

  printf '\n'
  log "Next steps:"
  for step in "${NEXT_STEPS[@]}"; do
    printf '  %s. %s\n' "$index" "$step"
    index=$((index + 1))
  done
}
