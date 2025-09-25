# For a slim CPU-only image, leave the CUDA_VERSION argument blank -- e.g.
# ARG CUDA_VERSION=
ARG CUDA_VERSION=12.1.0

# Calculate the base image based on CUDA_VERSION
ARG BASE_IMAGE=${CUDA_VERSION:+"nvidia/cuda:${CUDA_VERSION}-cudnn8-devel-ubuntu20.04"}
ARG BASE_IMAGE=${BASE_IMAGE:-"ubuntu:20.04"}

# Creates variables from arguments
FROM ${BASE_IMAGE} as base

# Labels for the docker
LABEL description="Docker for AI Research and Development" \
      repository="sytelus" \
      tag="latest" \
      creator="Shital Shah" \
      tooltype="pytorch" \
      tooltypeversion="2.1.0" \
      createtime="11/15/2023"

# for informational purposes
ENV DOCKER_TAG='sytelus/dev'

# Defines the base image
FROM base

# disable interactive prompts
ARG DEBIAN_FRONTEND=noninteractive

# Set the shell to bash so all next commands can use bash features
SHELL ["/bin/bash", "-c"]

ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,video,utility

# update cuda repository keys
# https://developer.nvidia.com/blog/updating-the-cuda-linux-gpg-repository-key/
RUN if [ -n "$CUDA_VERSION" ] ; then \
        rm -f /etc/apt/sources.list.d/cuda.list && \
        rm -f /etc/apt/sources.list.d/nvidia-ml.list && \
        apt-get update &&  \
        apt-get install -y --no-install-recommends wget && \
        apt-get autoclean && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* \
        apt-key del 7fa2af80 && \
        mkdir -p /tmp/cuda-keyring && \
        wget -P /tmp/cuda-keyring https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.0-1_all.deb && \
        dpkg -i /tmp/cuda-keyring/cuda-keyring_1.0-1_all.deb && \
        rm -rf /tmp/cuda-keyring ; \
    fi

# install basic pakages we might need
RUN apt-get -y update --fix-missing && \
    apt-get install --assume-yes --no-install-recommends --no-install-suggests \
        libgomp1 curl wget sudo build-essential software-properties-common \
        dirmngr apt-utils gpg-agent openssh-client less grep sed \
         tar apt-transport-https ca-certificates gnupg \
        # For PILLOW:
        zlib1g-dev libtiff-dev libfreetype6-dev liblcms2-dev tcl libjpeg8-dev \
        # For AWS EFA:
        autoconf autotools-dev automake libtool \
        # Development tools
        tmux cmake htop nvtop virt-what xclip xz-utils trash-cli bash-completion \
        tlp powertop tlp-rdw inxi procinfo nvidia-prime \
        libopencv-dev g++ libopenmpi-dev zlib1g-dev lsb-release \
        bzip2 libglib2.0-0 libxext6 libsm6 libxrender1 \
        fdupes locate \
        # For DeepSpeed
        libaio-dev libaio1 \
        # fun stuff
        fortune-mod sl espeak figlet sysvbanner cowsay oneko cmatrix toilet \
        pi xcowsay aview bb rig weather-util  \
        && \
    apt-get autoclean && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install latest version of git
RUN add-apt-repository ppa:git-core/ppa && \
    apt-get install -y --no-install-recommends \
        git && \
    apt-get autoclean && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install NodeJS (for Pyright)
RUN \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get autoclean && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Conda
# Set the environment variables
ENV ANACONDA_HOME=/opt/anaconda3
ENV PATH=$ANACONDA_HOME/bin:$PATH

# -b option is batch mode to silence licence terms prompt. It also won't modify .bashrc.
RUN wget --quiet https://repo.anaconda.com/archive/Anaconda3-2023.07-2-Linux-x86_64.sh -O /tmp/anaconda.sh  && \
        /bin/bash /tmp/anaconda.sh -b -p $ANACONDA_HOME && \
        rm /tmp/anaconda.sh

# Initialize conda for all users
RUN ln -s $ANACONDA_HOME/etc/profile.d/conda.sh /etc/profile.d/conda.sh \
    && echo ". $ANACONDA_HOME/etc/profile.d/conda.sh" >> /etc/skel/.bashrc \
    && echo "conda activate base" >> /etc/skel/.bashrc \
    && echo ". /opt/conda/etc/profile.d/conda.sh" >> "$HOME"/.bashrc \
    && echo "conda activate base" >> "$HOME"/.bashrc

# update to latest version
RUN conda update -y -n base -c defaults conda

# use much faster mamba solver
RUN conda install -y -n base conda-libmamba-solver
RUN conda config --set solver libmamba

# use base as default env
RUN conda config --set auto_activate_base true

RUN pip install --upgrade pip setuptools wheel

RUN pip install ninja

# Install cmake
RUN pip install cmake==3.27.7

# Install Pandoc Dependency
RUN pip install pandoc==2.3


# Install PyTorch
# Below two are only valid for PyTorch CUDA 12.1.0
ENV TORCH_INDEX_URL="https://download.pytorch.org/whl/cu121"
RUN conda install -y -n base pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia

# Install few utilities
RUN conda install -y -n base -c conda-forge gpustat scikit-learn-intelex py3nvml glances

# Install HuggingFace libs
RUN conda install -y -n base -c conda-forge transformers datasets tokenizers sentencepiece

# Install TensorFlow
RUN conda install -y -n base -c conda-forge tensorflow tensorboard keras

# Install other popular libraries
RUN pip install -q tiktoken wandb tqdm einops mlflow natsort \
    nbsphinx omegaconf pebble pre-commit pygtrie pytest \
    sphinx sphinx-book-theme matplotlib rich

# Updates TransformerEngine as v0.7 is not compatible with Flash-Attention 2
RUN pip uninstall -y transformer-engine \
    && git clone --branch stable --recursive https://github.com/NVIDIA/TransformerEngine.git \
    && cd TransformerEngine  \
    && export NVTE_FRAMEWORK=pytorch \
    && pip install . \
    && cd .. && rm -rf TransformerEngine

# Install Triton, needed for some ops in DeepSpeed
RUN pip install -q triton

# DeepSpeed and OpenMPI
ENV DEEPSPEED_VERSION="0.12.3"
RUN DS_BUILD_UTILS=1 DS_BUILD_OPS=1 DS_BUILD_FUSED_LAMB=1 DS_BUILD_FUSED_ADAM=1 \
    DS_BUILD_TRANSFORMER=1 DS_BUILD_TRANSFORMER_INFERENCE=1 \
    DS_BUILD_CUTLASS_OPS=0 DS_BUILD_RAGGED_DEVICE_OPS=0 DS_BUILD_EVOFORMER_ATTN=0 \
    DS_BUILD_SPARSE_ATTN=0 \
    pip install deepspeed==$DEEPSPEED_VERSION --global-option="build_ext" --global-option="-j8" && \
    CC=mpicc MPICC=mpicc pip install mpi4py --no-binary mpi4py

# Flash-Attention and CUDA extensions for cross-entropy, fused dense, layer norm, etc
ENV FLASH_ATTENTION_VERSION="2.3.3"
RUN git clone https://github.com/HazyResearch/flash-attention \
    && cd flash-attention && git checkout v$FLASH_ATTENTION_VERSION \
    && python setup.py install \
    && FLASH_ATTENTION_FORCE_BUILD=TRUE pip install . \
    && cd csrc/fused_softmax && pip install . && cd ../../ \
    && cd csrc/rotary && pip install . && cd ../../ \
    && cd csrc/xentropy && pip install . && cd ../../ \
    && cd csrc/layer_norm && pip install . && cd ../../ \
    && cd csrc/fused_dense_lib && pip install . && cd ../../ \
    && cd .. && rm -rf flash-attention

# xFormers (without dependencies to avoid clashing with PyTorch)
ENV XFORMERS_VERSION="0.0.22.post7"
RUN pip install --no-dependencies xformers --index-url $TORCH_INDEX_URL

# Additional packages that prevents pip uninstalling when running on the cluster
RUN pip install -q accelerate azureml-mlflow datasets einops evaluate mlflow natsort omegaconf \
    pebble pre-commit pygtrie pytest tokenizers transformers typing-extensions wandb

# add user for doing sudo
# su - docker_admin -c "sudo adduser $USER sudo"
# create user with home dir (-m), UID=1000 (-u), and same group as user (-U)
RUN useradd -m docker_admin -s /bin/bash -u 1000 -U
RUN usermod -aG sudo docker_admin
RUN passwd -x -1 docker_admin && passwd -d docker_admin
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# ----- end of main Dockerfile -----

# ARG INSTALLER_IMAGE
# ARG VALIDATOR_IMAGE

# FROM $INSTALLER_IMAGE as installer
# FROM $VALIDATOR_IMAGE as validator

# # Retrieves and install Singularity script
# COPY --from=installer /installer /opt/microsoft/_singularity/installations/
# RUN /opt/microsoft/_singularity/installations/singularity/installer.sh

# # Sets some validation environment variables for additional checks
# ENV SINGULARITY_IMAGE_ACCELERATOR="NVIDIA"

# # Retrieves and validates Singularity script
# COPY --from=validator /validations /opt/microsoft/_singularity/validations/
# RUN /opt/microsoft/_singularity/validations/validator.sh
