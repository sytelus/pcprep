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

bash anaconda.sh
bash ml.sh
