# run this as:
# curl -s https://github.com/sytelus/pcprep/blob/master/ubuntu/web_install.sh | bash

set -eu -o pipefail -o xtrace # fail if any command failes, log all commands, -o xtrace

pushd ~
mkdir -p GitHubSrc
cd GitHubSrc
git clone https://github.com/sytelus/pcprep.git
cd pcprep/ubuntu
bash prepare_new_box.sh
popd