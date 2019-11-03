#!/bin/bash
#fail if any errors
set -e
set -o xtrace

mkdir -p ~/GitHubSrc
pushd ~/GitHubSrc

function install_from_git {
	if [ -d "~/GitHubSrc/$2" ]; then
		git clone https://github.com/$1/$2.git
		cd "$2"
		pip install -e .
		cd ..	
	fi
}

install_from_git microsoft tensorwatch
install_from_git sytelus podworld
install_from_git sytelus regim
install_from_git hill-a stable-baselines
install_from_git openai spinningup

[ ! -d 'AirSim' ] && git clone https://github.com/microsoft/AirSim.git
[ ! -d 'shitalshah.com-v5' ] && git clone https://github.com/sytelus/shitalshah.com-v5.git
[ ! -d 'gymexp' ] && git clone https://github.com/sytelus/gymexp.git
[ ! -d 'dsvm_utils' ] && git clone https://github.com/sytelus/dsvm_utils.git
[ ! -d 'rl-experiments' ] && https://github.com/sytelus/rl-experiments.git
[ ! -d 'rl-experiments' ] && https://github.com/sytelus/rl-baselines-zoo.git

popd
