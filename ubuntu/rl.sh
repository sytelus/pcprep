pip install -q gym
conda install -y pystan swig

pip install -q gym[box2d]
pip install -q gym[classic_control]
pip install -q gym[atari]

pip install ray[rllib]

#DSVM needs additional installs for stable-baselines
sudo apt-get -y update
sudo apt-get -y install swig cmake libopenmpi-dev zlib1g-dev
#conda install -y x264=='1!152.20180717' ffmpeg=4.0.2 -c conda-forge
pip install -q stable-baselines[mpi] box2d box2d-kengz pyyaml pybullet optuna pytablewriter scikit-optimize
