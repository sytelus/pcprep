#!/bin/bash
#fail if any errors
set -e
set -o xtrace

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
    read -p "Enter your name: " user_name
fi
if [ -z "${user_email:-}" ]; then
    read -p "Enter your email: " user_email
fi

# Set global Git configurations using the user's input
git config --global user.name "$user_name"
git config --global user.email "$user_email"
# git config --global url.ssh://git@github.com/.insteadOf https://github.com/

# set default line ending to LF
git config --global core.eol lf
# convert line endings from CRLF to LF but not the other way around
git config --global core.autocrlf input

git config --global merge.tool vscode
git config --global mergetool.vscode.cmd "code --wait $MERGED"
git config --global diff.tool vscode
git config --global difftool.vscode.cmd "code --wait --diff $LOCAL $REMOTE"
git config --global core.editor "code --new-window -wait"



