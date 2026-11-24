#!/bin/sh
# Git's editor, installed by gitconfig.sh. Uses VS Code when it can open a
# window from this terminal (a VS Code terminal, WSL or a desktop session), so
# plain SSH sessions on a server get a terminal editor instead of a failed
# `code --wait`.
if command -v code >/dev/null 2>&1 && {
    [ "${TERM_PROGRAM:-}" = vscode ] || [ -n "${VSCODE_IPC_HOOK_CLI:-}" ] ||
        [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]
}; then
    exec code --new-window --wait "$@"
fi
for editor in "${VISUAL:-}" "${EDITOR:-}"; do
    case $editor in
        '' | *git_editor.sh*) ;;
        *) exec sh -c "$editor \"\$@\"" "$editor" "$@" ;;
    esac
done
for editor in micro vim nano vi; do
    if command -v "$editor" >/dev/null 2>&1; then
        exec "$editor" "$@"
    fi
done
echo "No editor found. Install micro, vim or nano, or set GIT_EDITOR." >&2
exit 1
