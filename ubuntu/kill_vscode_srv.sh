#!/usr/bin/env bash
set -Eeuo pipefail

command -v realpath >/dev/null 2>&1 || { echo "realpath is required" >&2; exit 1; }
HOME_ROOT=$(realpath -m -- "${HOME:?HOME is required}")
[[ $HOME_ROOT == /* && $HOME_ROOT != / ]] \
  || { echo "Refusing unsafe HOME: $HOME_ROOT" >&2; exit 1; }
TARGET="$HOME_ROOT/.vscode-server"

[[ -e $TARGET ]] || { echo "VS Code server state is already absent: $TARGET"; exit 0; }
if [[ ${1:-} != --yes ]]; then
  read -r -p "Delete VS Code server state at $TARGET? Type DELETE to continue: " answer
  [[ $answer == DELETE ]] || { echo "Cancelled."; exit 1; }
fi
if [[ ${PCPREP_SKIP_PROCESS_KILL:-0} != 1 ]]; then
  pkill -u "$USER" -f '[v]scode-server' || true
fi
rm -rf -- "$TARGET"
[[ ! -e $TARGET ]] || { echo "Deletion failed: $TARGET" >&2; exit 1; }
echo "Deleted VS Code server state: $TARGET"
