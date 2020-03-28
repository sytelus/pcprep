REM CUDA 10.0****************************************
REM Install CUDA 10.0 https://developer.nvidia.com/compute/cuda/10.0/Prod/network_installers/cuda_10.0.130_win10_network
REM Install cuDNN 7.6 https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.4.38/Production/10.0_20190923/cudnn-10.0-windows10-x64-v7.6.4.38.zip
REM	Extract zip file to C:\Program Files\cuDNN7, add path to C:\Program Files\cuDNN7\cuda\bin

REM CUDA 10.1****************************************
REM Install CUDA 10.1 https://developer.nvidia.com/cuda-downloads?target_os=Windows&target_arch=x86_64&target_version=10
REM Install cuDNN 7.6 https://developer.nvidia.com/rdp/cudnn-download
REM	Extract zip file to C:\Program Files\cuDNN7, add path to C:\Program Files\cuDNN7\cuda\bin

call conda install -y pytorch torchvision cudatoolkit=10.1 -c pytorch
pip install -q -tensorflow
pip install -q tensorboard keras tensorboardX keras-vis visdom receptivefield optuna
