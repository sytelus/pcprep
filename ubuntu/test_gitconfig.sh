#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin"
cat > "$TEST_ROOT/bin/code" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$PCPREP_CODE_ARGS"
FAKE
chmod +x "$TEST_ROOT/bin/code"

export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL="$TEST_ROOT/gitconfig"
export PATH="$TEST_ROOT/bin:$PATH"
export user_name='pcprep test'
export user_email='pcprep-test@example.invalid'
bash "$SCRIPT_DIR/gitconfig.sh" </dev/null

[[ $(git config --global core.editor) == 'code --new-window --wait' ]]
[[ $(git config --global mergetool.vscode.cmd) == 'code --wait "$MERGED"' ]]
[[ $(git config --global difftool.vscode.cmd) == 'code --wait --diff "$LOCAL" "$REMOTE"' ]]

export PCPREP_CODE_ARGS="$TEST_ROOT/merge.args"
MERGED="$TEST_ROOT/merged file" sh -c "$(git config --global mergetool.vscode.cmd)"
mapfile -t merge_args < "$PCPREP_CODE_ARGS"
[[ ${merge_args[0]} == --wait && ${merge_args[1]} == "$TEST_ROOT/merged file" ]]

export PCPREP_CODE_ARGS="$TEST_ROOT/diff.args"
LOCAL="$TEST_ROOT/local file" REMOTE="$TEST_ROOT/remote file" \
  sh -c "$(git config --global difftool.vscode.cmd)"
mapfile -t diff_args < "$PCPREP_CODE_ARGS"
[[ ${diff_args[0]} == --wait && ${diff_args[1]} == --diff ]]
[[ ${diff_args[2]} == "$TEST_ROOT/local file" && ${diff_args[3]} == "$TEST_ROOT/remote file" ]]

if user_name=' ' user_email='pcprep-test@example.invalid' \
    bash "$SCRIPT_DIR/gitconfig.sh" </dev/null >/dev/null 2>&1; then
  echo "gitconfig accepted a blank Git user name." >&2
  exit 1
fi
if user_name='pcprep test' user_email=$'first@example.invalid\nsecond@example.invalid' \
    bash "$SCRIPT_DIR/gitconfig.sh" </dev/null >/dev/null 2>&1; then
  echo "gitconfig accepted a multiline Git email." >&2
  exit 1
fi

echo "gitconfig tool-command tests passed"
