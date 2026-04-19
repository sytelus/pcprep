#!/usr/bin/env bash
# Shared helper functions for the macOS bootstrap scripts.
# Keep this file Bash 3.2 compatible because a fresh macOS install still ships
# an older Bash in /bin/bash.

set -u

PCPREP_PREFIX="[pcprep-mac]"

# Initialize the deferred user-message queue here so scripts that source this
# file without first declaring the array (e.g. setup_python_ai.sh) can still
# call append_next_step without tripping `set -u`. Using "+x" leaves any array
# the caller already populated intact.
if [ -z "${NEXT_STEPS+x}" ]; then
  NEXT_STEPS=()
fi

log() {
  printf '%s[INFO] %s\n' "$PCPREP_PREFIX" "$*"
}

warn() {
  printf '%s[WARN] %s\n' "$PCPREP_PREFIX" "$*" >&2
}

die() {
  printf '%s[ERROR] %s\n' "$PCPREP_PREFIX" "$*" >&2
  exit 1
}

on_err() {
  local failed_command="$1"
  local failed_line="$2"
  local failed_status="$3"

  printf '%s[ERROR] Command failed with exit code %s at line %s: %s\n' \
    "$PCPREP_PREFIX" "$failed_status" "$failed_line" "$failed_command" >&2
  exit "$failed_status"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

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

is_interactive() {
  [ -t 0 ] && [ -t 1 ]
}

require_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    die "These scripts only support macOS. Detected: $(uname -s)"
  fi
}

ensure_dir() {
  mkdir -p "$1"
}

ensure_file() {
  local target_file="$1"
  ensure_dir "$(dirname "$target_file")"
  touch "$target_file"
}

ensure_line_in_file() {
  local target_file="$1"
  local expected_line="$2"

  ensure_file "$target_file"

  if ! grep -Fqx "$expected_line" "$target_file"; then
    printf '%s\n' "$expected_line" >> "$target_file"
  fi
}

upsert_managed_block() {
  local target_file="$1"
  local block_start="$2"
  local block_end="$3"
  local block_content="$4"
  local temp_file

  ensure_file "$target_file"
  temp_file="$(mktemp "${TMPDIR:-/tmp}/pcprep-mac.XXXXXX")"

  awk -v start="$block_start" -v end="$block_end" '
    $0 == start { skip = 1; next }
    $0 == end   { skip = 0; next }
    skip != 1   { print }
  ' "$target_file" > "$temp_file"

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

has_internet() {
  # Prefer a lightweight HTTPS probe because many networks block ICMP.
  if command_exists curl; then
    curl -fsSI --max-time 5 https://clients3.google.com/generate_204 >/dev/null 2>&1 && return 0
    curl -fsSI --max-time 5 https://www.apple.com >/dev/null 2>&1 && return 0
  fi

  return 1
}

run_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

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

append_next_step() {
  NEXT_STEPS+=("$1")
}

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
