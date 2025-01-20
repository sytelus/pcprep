# run this as:
# curl -LO https://raw.githubusercontent.com/sytelus/pcprep/refs/heads/master/ubuntu/setupbox.sh && chmod +x setupbox.sh && ./setupbox.sh


set -eu -o pipefail -o xtrace # fail if any command failes, log all commands, -o xtrace

pushd ~
mkdir -p GitHubSrc
cd GitHubSrc
git clone https://github.com/sytelus/pcprep.git
cd pcprep/ubuntu
bash prepare_new_box.sh
popd