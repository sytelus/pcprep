#!/bin/bash
#fail if any errors
set -e
set -o xtrace

wget https://repo.anaconda.com/archive/Anaconda3-2019.10-Linux-x86_64.sh -O ~/anaconda.sh
bash ~/anaconda.sh

# needed to avoid opencv hdf5 conflicts
conda update  -y --all 