#!/bin/bash
#fail if any errors
set -e
set -o xtrace

USER_BASHRC="$HOME/.bashrc"
DEFAULT_BASHRC="/etc/skel/.bashrc"


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

cp -vn .bash_aliases ~/.bash_aliases
cp -vn .inputrc ~/.inputrc
cp -vn .tmux.conf ~/.tmux.conf

# copy some useful utils as .sh files
chmod +x *.sh
cp -vn rundocker.sh ~/.local/bin/rundocker.sh
cp -vn azmount.yaml ~/.local/bin/azmount.yaml
cp -vn azmount.sh ~/.local/bin/azmount.sh
cp -vn mount_cifs.sh ~/.local/bin/mount_cifs.sh
cp -vn start_tmux.sh ~/.local/bin/start_tmux.sh
cp -vn sysinfo.sh ~/.local/bin/sysinfo.sh
cp -vn treesize.sh ~/.local/bin/treesize.sh
cp -vn measure_flops.py ~/.local/bin/measure_flops.py

# skip files that already exists
cp -vrn .config/ ~/
cp -vrn .ssh/ ~/
cp -vrn .local/ ~/


# create local bin where we can store our apps as sudo is not supported
mkdir -p ~/.local/bin
statement='export PATH="$HOME/.local/bin:$PATH"'
bashrc="$HOME/.bashrc"
if ! grep -qF "$statement" "$bashrc"; then
    echo "" >> "$bashrc"
    echo "$statement" >> "$bashrc"
    . "$bashrc"
fi
