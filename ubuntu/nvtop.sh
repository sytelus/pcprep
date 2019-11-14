#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# Ubuntu 19 onwards nvtop can be installed by sudo apt

mkdir -p ~/GitHubSrc
pushd ~/GitHubSrc

sudo apt -y install cmake libncurses5-dev libncursesw5-dev git

# clone if not already exist
[ ! -d 'nvtop' ] && git clone https://github.com/Syllo/nvtop.git
mkdir -p nvtop/build && cd nvtop/build

# if conda environment then first deactivate it
env="${CONDA_DEFAULT_ENV}"
if [[ ! -z "${env}" ]]; then
    # https://github.com/conda/conda/issues/7980#issuecomment-524154596
    eval "$(conda shell.bash hook)"
    conda deactivate
fi
cmake ..

# If it errors with "Could NOT find NVML (missing: NVML_INCLUDE_DIRS)"
# try the following command instead, otherwise skip to the build with make.
cmake .. -DNVML_RETRIEVE_HEADER_ONLINE=True

make
sudo make install # You may need sufficient permission for that (root)

# reactivate conda environment
if [[ ! -z "${env}" ]]; then
    conda activate "${env}"
fi
popd