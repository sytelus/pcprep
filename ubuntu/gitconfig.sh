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
git config --global user.name "Shital Shah"
git config --global user.email "shitals@microsoft.com"
# git config --global core.editor "'C:/Program Files (x86)/Notepad++/notepad++.exe' -multiInst -notabbar -nosession -noPlugin"
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd "code --wait $MERGED"
git config --global diff.tool vscode
git config --global difftool.vscode.cmd "code --wait --diff $LOCAL $REMOTE"
git config --global core.editor "code --new-window -wait"


if [ ! -d "/dsvm/" ]; then
    git config --global url."git@github.com:".insteadOf "https://github.com/"
fi

