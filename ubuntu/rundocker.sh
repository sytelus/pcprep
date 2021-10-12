docker run --gpus all -d --name archai \
    -u $(id -u):$(id -g) \
    -e HOME=$HOME -e USER=$USER \
    -v $HOME:$HOME \
    -v /dataroot:$HOME/dataroot \
    --ipc=host \
    --net=host \
    -it sytelus/archai