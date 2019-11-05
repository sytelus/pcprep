pip install -q gym
conda install -y pystan swig

pip install -q gym[box2d]
pip install -q gym[classic_control]
pip install -q gym[atari]

# necessory packages for Ray
pip install -q filelock tabulate aiohttp psutil
# below assumes npm 12.x is already installed
pushd ~/GitHubSrc
# ---- ray install starts
git clone https://github.com/ray-project/ray.git

# Install Bazel.
ray/ci/travis/install-bazel.sh

# Optionally build the dashboard 
pushd ray/python/ray/dashboard/client
npm ci
npm run build
popd

# Install Ray.
cd ray/python
pip install -e . --verbose 
#---- ray install ends
popd

#pip install ray[rllib]
#pip install ray[tune]
#pip install ray[debug]

#DSVM needs additional installs for stable-baselines
sudo apt-get -y update
sudo apt-get -y install swig cmake libopenmpi-dev zlib1g-dev
#conda install -y x264=='1!152.20180717' ffmpeg=4.0.2 -c conda-forge
pip install -q stable-baselines[mpi] box2d box2d-kengz pyyaml pybullet optuna pytablewriter scikit-optimize
