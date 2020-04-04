#!/bin/bash
#fail if any errors
set -e
set -o xtrace

if [ ! -d ~/anaconda3/ ]; then
    wget https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh -O ~/anaconda.sh
    bash ~/anaconda.sh

    # needed to avoid opencv hdf5 conflicts
    #conda update  -y --all
else
    echo *********** anaonda instalation found so it will be skipped
fi