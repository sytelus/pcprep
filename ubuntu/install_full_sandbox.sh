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
rm ~/anaconda.sh
# sudo ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh
# sudo chown -R $USER /opt/cond
# sudo chown -R $USER ~/.conda

# modify .bashrc
~/anaconda3/bin/conda init bash
conda config --set auto_activate_base true

# update to latest version
conda update -n base -c defaults conda

# use much faster mamba solver
conda install -n base conda-libmamba-solver
conda config --set solver libmamba

# get conda changes in effect
source ~/.bashrc

conda activate base

# install CUDA
conda install cuda -c nvidia/label/cuda-12.1.0
conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia/label/cuda-12.1.0


conda install -y -c conda-forge tensorflow
conda install -y -c conda-forge tensorboard keras
conda install -y -c conda-forge gpustat scikit-learn-intelex py3nvml glances
pip install -q transformers datasets wandb accelerate einops tokenizers sentencepiece

