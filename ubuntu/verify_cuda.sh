set -o xtrace

# validation
# driver version
cat /proc/driver/nvidia/version

cat $(whereis cudnn.h) | grep CUDNN_MAJOR -A 2
cat $(whereis cuda)/include/cudnn.h | grep CUDNN_MAJOR -A 2
which nvcc
which nvidia-smi

nvcc --version

nvidia-smi

# cuda validation
pushd ~/GitHubSrc
git clone https://github.com/nvidia/cuda-samples
cd cuda-samples/Samples/1_Utilities/deviceQuery
make
./deviceQuery

# cuDNN validation (doesn't work due to FreeImage.h)
cp -r /usr/src/cudnn_samples_v8/ $HOME
cd  $HOME/cudnn_samples_v8/mnistCUDNN
make clean && make
./mnistCUDNN

popd