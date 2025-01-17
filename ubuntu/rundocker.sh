# ref: https://catalog.ngc.nvidia.com/orgs/nvidia/containers/pytorch
# ref: https://www.pugetsystems.com/labs/hpc/How-To-Setup-NVIDIA-Docker-and-NGC-Registry-on-your-Workstation---Part-5-Docker-Performance-and-Resource-Tuning-1119/

# this command makes available dev environment on new VMs
# additional drives can be mapped using: -v ~/azblob/dataroot:$HOME/dataroot

#     -e NCCL_P2P_LEVEL=NVL \

# NVIDIA_DRIVER_CAPABILITIES: Specifies the driver capabilities.
# NVIDIA_VISIBLE_DEVICES: Specifies the visible devices.
# __NV_PRIME_RENDER_OFFLOAD: Specifies the prime render offload.
# __GLX_VENDOR_LIBRARY_NAME: Specifies the GLX vendor library name.

# -v option is used to mount the host directory to the container directory.
# we also need to mount BIG_DISK which will have the data etc (see .bashrc)

docker run --gpus all --name dev_container \
    --rm \
    -u $(id -u):$(id -g) \
    -e HOME=$HOME -e USER=$USER \
    -v $HOME:$HOME \
    -v $BIG_DISK:$BIG_DISK \
    -w $HOME \
    --ipc=host \
    --ulimit memlock=-1 \
    --net=host \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e __NV_PRIME_RENDER_OFFLOAD=1 \
    -e __GLX_VENDOR_LIBRARY_NAME=nvidia \
    -it ${1:-pytorch/pytorch:2.5.1-cuda12.4-cudnn9-devel} /bin/bash
    # can also ise image: docker://@nvcr.io#nvidia/pytorch:24.07-py3