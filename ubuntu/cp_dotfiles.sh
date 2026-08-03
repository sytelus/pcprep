#!/bin/bash
#fail if any errors
set -e
set -o xtrace

USER_BASHRC="$HOME/.bashrc"
DEFAULT_BASHRC="/etc/skel/.bashrc"

# GNU coreutils 9.7 warns that `cp -n` is deprecated, while the 8.32 version
# in Ubuntu 22.04 does not support `--update=none`. Select the equivalent
# no-clobber spelling supported by the running WSL/Ubuntu release.
CP_NO_CLOBBER=(-n)
if cp --help 2>&1 | grep -F -- '--update=UPDATE' >/dev/null; then
    CP_NO_CLOBBER=(--update=none)
fi

check_bashrc_modification() {
    # Check if user's .bashrc exists
    if [ ! -f "$USER_BASHRC" ]; then
        echo "Error: .bashrc doesn't exist in the user's home directory." >&2
        return 1
    fi

    # Check if default .bashrc exists
    if [ ! -f "$DEFAULT_BASHRC" ]; then
        echo "Error: Default .bashrc not found. Unable to compare." >&2
        return 1
    fi

    # Compare the files
    if diff -q "$USER_BASHRC" "$DEFAULT_BASHRC" >/dev/null; then
        # Files are identical
        return 1
    else
        # Files are different
        return 0
    fi
}

# Example usage in an if statement:
if check_bashrc_modification; then
    echo ".bashrc has been modified from the default version and will not be replaced."
else
    cp -f .bashrc ~/.bashrc
fi

cp -v "${CP_NO_CLOBBER[@]}" .bash_aliases ~/.bash_aliases
cp -v "${CP_NO_CLOBBER[@]}" .inputrc ~/.inputrc
cp -v "${CP_NO_CLOBBER[@]}" .tmux.conf ~/.tmux.conf
mkdir -p ~/.codex
cp -v "${CP_NO_CLOBBER[@]}" .codex/config.toml ~/.codex/config.toml
mkdir -p ~/.claude
cp -v "${CP_NO_CLOBBER[@]}" .claude/settings.json ~/.claude/settings.json

# Skip files that already exist.
cp -vr "${CP_NO_CLOBBER[@]}" .config/ ~/
cp -vr "${CP_NO_CLOBBER[@]}" .ssh/ ~/
cp -vr "${CP_NO_CLOBBER[@]}" .local/ ~/


# create local bin where we can store our apps as sudo is not supported
mkdir -p ~/.local/bin
statement='export PATH="$HOME/.local/bin:$PATH"'
bashrc="$HOME/.bashrc"
if ! grep -qF "$statement" "$bashrc"; then
    echo "" >> "$bashrc"
    echo "$statement" >> "$bashrc"
    . "$bashrc"
fi

# Copy Linux helpers without changing executable bits in the repository.
cp -vn rundocker.sh ~/.local/bin/rundocker.sh
cp -vn azmount.sh ~/.local/bin/azmount.sh
cp -vn azunmount.sh ~/.local/bin/azunmount.sh
cp -vn mount_cifs.sh ~/.local/bin/mount_cifs.sh
cp -vn start_tmux.sh ~/.local/bin/start_tmux.sh
cp -vn sysinfo.sh ~/.local/bin/sysinfo.sh
cp -vn treesize.sh ~/.local/bin/treesize.sh
cp -vn measure_flops.py ~/.local/bin/measure_flops.py
cp -vn kill_vscode_srv.sh ~/.local/bin/kill_vscode_srv.sh
cp -vn security_status.sh ~/.local/bin/security_status.sh
cp -vn unban.sh ~/.local/bin/unban.sh
chmod +x ~/.local/bin/rundocker.sh ~/.local/bin/azmount.sh ~/.local/bin/azunmount.sh \
  ~/.local/bin/mount_cifs.sh ~/.local/bin/start_tmux.sh ~/.local/bin/sysinfo.sh \
  ~/.local/bin/treesize.sh ~/.local/bin/measure_flops.py \
  ~/.local/bin/kill_vscode_srv.sh ~/.local/bin/security_status.sh ~/.local/bin/unban.sh

AZ_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pcprep"
mkdir -p "$AZ_CONFIG_DIR"
if [ ! -e "$AZ_CONFIG_DIR/azmount.yaml" ]; then
    sed "s|YOUR_HOME|$HOME|g" azmount.yaml > "$AZ_CONFIG_DIR/azmount.yaml"
    chmod 0600 "$AZ_CONFIG_DIR/azmount.yaml"
fi
