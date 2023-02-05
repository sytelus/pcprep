# ref: https://catalog.ngc.nvidia.com/orgs/nvidia/containers/pytorch
# ref: https://www.pugetsystems.com/labs/hpc/How-To-Setup-NVIDIA-Docker-and-NGC-Registry-on-your-Workstation---Part-5-Docker-Performance-and-Resource-Tuning-1119/

# this command makes available dev environment on new VMs
# additional drives can be mapped using: -v ~/azblob/dataroot:$HOME/dataroot

docker run --gpus all --name archai \
    --rm \
    -u $(id -u):$(id -g) \
    -e HOME=$HOME -e USER=$USER \
    -e NCCL_P2P_LEVEL=NVL \
    -v $HOME:$HOME \
    -w $HOME \
    --shm-size=10g \
    --ulimit memlock=-1 \
    --net=host \
    -it sytelus/dev