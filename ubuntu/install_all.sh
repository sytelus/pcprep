#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# install VS code, dropbox, chrome: https://code.visualstudio.com/, anaconda.sh

# for WSL get GitHubSrc from host
#ln -s /mnt/d/GitHubSrc/ GitHubSrc

bash cp_dotfiles.sh
bash gsettings.sh

bash min_system.sh
bash gitconfig.sh

if [ ! -d "/dsvm/" ]; then
    bash anaconda.sh
    bash python.sh
    bash ml.sh
fi

# if we are in Azure DSVM, don't install all these stuff
if [ ! -d "/dsvm/" ] && ["$HOSTNAME" != "GCRSANDBOX"*]; then
    bash system.sh
    # install cuda only if we are not in WSL
    if [[ -z "$WSL_DISTRO_NAME" ]]; then
        bash cuda.sh
    fi
    bash rl.sh

    if [[ -z "$WSL_DISTRO_NAME" ]]; then
        bash apex.sh
        bash gitclones.sh
    fi
else
    # the default is anaconda 2ith Python 2.7
    echo Please re-login so dot files takes effect and rerun this script.
    exit 0
fi


echo "Install all done."