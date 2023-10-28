
pip install -q packaging ninja

rm -rf ~/GitHubSrc/flash-attention/
mkdir -p ~/GitHubSrc
pushd ~/GitHubSrc
# Clone the main repository and checkout specific version
git clone --depth=1 --branch main https://github.com/HazyResearch/flash-attention.git  --single-branch
cd flash-attention

# Install the main project (`setup.py` is preferable for better compatibility)
# `pip install .` will force package override if the package is already installed
python setup.py install
pip install -e .

SUBREPOS=("csrc/fused_softmax" "csrc/rotary" "csrc/xentropy" "csrc/fused_dense_lib" "csrc/layer_norm")

# Install subrepositories using `pip`
for subrepo in "${SUBREPOS[@]}"; do
    cd "$subrepo"
    pip install -e .
    cd ..
done

popd

