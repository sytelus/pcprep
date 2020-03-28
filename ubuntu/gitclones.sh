#!/bin/bash
#fail if any errors
set -e
set -o xtrace

mkdir -p ~/GitHubSrc
pushd ~/GitHubSrc

function install_from_git {
	if [ ! -d ~/GitHubSrc/$2 ]; then
		git clone https://github.com/$1/$2.git
		cd "$2"
		pip install -e .
		cd ..	
	fi
}

if [ ! -d "/dsvm/" ]; then
	# tensorflow 1.14 incompatibility
	install_from_git openai spinningup
fi

install_from_git microsoft tensorwatch
install_from_git sytelus podworld
install_from_git sytelus regim
install_from_git sytelus archai
install_from_git sytelus cifar_testbed
install_from_git hill-a stable-baselines

[ ! -d 'AirSim' ] && git clone https://github.com/microsoft/AirSim.git
[ ! -d 'shitalshah.com-v5' ] && git clone https://github.com/sytelus/shitalshah.com-v5.git
[ ! -d 'gymexp' ] && git clone https://github.com/sytelus/gymexp.git
[ ! -d 'pcprep' ] && git clone https://github.com/sytelus/pcprep.git
[ ! -d 'rl-experiments' ] && git clone https://github.com/sytelus/rl-experiments.git
[ ! -d 'rl-baselines-zoo' ] && git clone https://github.com/sytelus/rl-baselines-zoo.git

# TODO: Move this to above structure
set +e
git clone https://github.com/dragen1860/DARTS-PyTorch.git
git clone https://github.com/khanrc/pt.darts.git
git clone https://github.com/kakaobrain/fast-autoaugment.git
git clone https://github.com/microsoft/petridishnn.git
git clone https://github.com/debadeepta/archaiphilly.git
git clone https://github.com/vfdev-5/cifar10-faster.git
git clone https://github.com/apple/ml-cifar-10-faster.git
git clone https://github.com/davidcpage/cifar10-fast.git
git clone https://github.com/sytelus/cifar_testbed.git
git clone https://github.com/sytelus/archai.git

popd
