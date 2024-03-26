#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# This installs anaconda and other libs on top of install_sandbox.sh

# this commands are same as in Dockerfile

# install core packages
bash cp_dotfiles.sh
bash min_system.sh
bash gitconfig.sh

sudo apt-get clean

wget https://repo.anaconda.com/archive/Anaconda3-2023.07-2-Linux-x86_64.sh -O ~/anaconda.sh
# batch install: agree to licence and install to ~/anaconda3
/bin/bash ~/anaconda.sh -b -p $HOME/anaconda3
#rm ~/anaconda.sh
# sudo ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh
# sudo chown -R $USER /opt/cond
# sudo chown -R $USER ~/.conda

# modify .bashrc
~/anaconda3/bin/conda init bash
conda config --set auto_activate_base true

# update to latest version
conda update -n base -c defaults conda

# (already setup in new conda) use much faster mamba solver
# conda install -n base conda-libmamba-solver
# conda config --set solver libmamba

# get conda changes in effect
source ~/.bashrc

conda activate base

# install Poetry
curl -sSL https://install.python-poetry.org | python3 -

# perms to install az extensions
sudo chmod 777 /opt/az/extensions/

bash install_dl_frameworks.sh

