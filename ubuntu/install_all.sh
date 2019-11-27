#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# install VS code, dropbox, chrome: https://code.visualstudio.com/, anaconda.sh

bash cp_dotfiles.sh

# if we are in Azure DSVM, don't install all these stuff
if [ ! -d "/dsvm/" ]; then
    bash system.sh
    bash gitconfig.sh
    bash anaconda.sh
    bash python.sh
    # install cuda only if we are not in WSL
    if [ -z "$IS_WSL" ]; then
        bash cuda.sh
    fi
    bash ml.sh
else
    # the default is anaconda 2ith Python 2.7
    echo Please relogin so dot files takes effect and rerun this script.
    exit 0
fi
bash rl.sh
bash gitclones.sh

echo "Install all done."