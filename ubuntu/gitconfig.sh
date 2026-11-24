#!/bin/bash
#fail if any errors
set -e

# git config --global merge.tool bc trustExitCode true
# git config --global mergetool.bc.path "c:/Program Files/Beyond Compare 4/bcomp.exe"
# git config --global diff.tool bc trustExitCode true
# git config --global difftool.bc.path "c:/Program Files/Beyond Compare 4/bcomp.exe"
# git config --global --add difftool.prompt false
# git config --global core.autocrlf true
#!/bin/bash

# Prompt the user for their name and email
# Prompt only if not already set via environment
if [ -z "${user_name:-}" ]; then
    read -r -p "Enter your git username: " user_name
fi
if [ -z "${user_email:-}" ]; then
    read -r -p "Enter your git email: " user_email
fi

[[ $user_name != *$'\n'* && $user_name != *$'\r'* && $user_name =~ [^[:space:]] ]] \
    || { echo "Git user name must be a nonblank, single-line value." >&2; exit 1; }
[[ $user_email != *$'\n'* && $user_email != *$'\r'* && $user_email =~ [^[:space:]] ]] \
    || { echo "Git email must be a nonblank, single-line value." >&2; exit 1; }

# Set global Git configurations using the user's input
git config --global user.name "$user_name"
git config --global user.email "$user_email"
# Remove only the exact rewrite installed by older Ubuntu bootstraps.
# Git returns 5 when there is nothing to remove. Propagate other errors.
git config --global --fixed-value --unset-all url.ssh://git@github.com/.insteadOf https://github.com/ \
    || { status=$?; [ "$status" -eq 5 ] || exit "$status"; }

# set default line ending to LF
git config --global core.eol lf
# convert line endings from CRLF to LF but not the other way around
git config --global core.autocrlf input

git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait "$MERGED"'
git config --global diff.tool vscode
git config --global difftool.vscode.cmd 'code --wait --diff "$LOCAL" "$REMOTE"'
# VS Code when it can open a window, otherwise a terminal editor (plain SSH).
editor_path="$HOME/.local/bin/git_editor.sh"
mkdir -p "$HOME/.local/bin"
install -m 0755 "$(dirname -- "${BASH_SOURCE[0]}")/git_editor.sh" "$editor_path"
printf -v editor_command '%q' "$editor_path"
git config --global core.editor "$editor_command"

# if repo doesn't have latest, by default try rebase first
git config --global pull.rebase true
