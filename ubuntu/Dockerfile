# from https://catalog.ngc.nvidia.com/orgs/nvidia/containers/pytorch/tags
FROM nvcr.io/nvidia/pytorch:22.12-py3

# Labels for the docker
LABEL description="Docker for AI Research and Development" \
      repository="sytelus" \
      tag="latest" \
      creator="Shital Shah" \
      tooltype="pytorch" \
      tooltypeversion="1.0.0" \
      createtime="2/1/2023"

# for informational purposes
ENV DOCKER_TAG='sytelus/dev'

# From min_system.sh
RUN apt-get -y update --fix-missing
RUN DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes --no-install-recommends \
      git curl wget xclip xz-utils tar apt-transport-https trash-cli bash-completion \
      tlp powertop tlp-rdw inxi procinfo nvidia-prime htop #conky-all #conky-cli \
      build-essential cmake libopencv-dev g++ libopenmpi-dev zlib1g-dev \
      fortune-mod sl espeak figlet sysvbanner cowsay oneko cmatrix toilet pi xcowsay aview bb rig weather-util ponysay \
      fslint fdupes locate \
      apt-transport-https ca-certificates curl gnupg lsb-release \
      bzip2 libglib2.0-0 libxext6 libsm6 libxrender1 mercurial subversion \
      nvtop virt-what sudo

RUN apt-get clean

# -b option is batch mode to silence licence terms prompt. It also won't modify .batchrc.
RUN wget --quiet https://repo.anaconda.com/archive/Anaconda3-2022.10-Linux-x86_64.sh -O ~/anaconda.sh  && \
        /bin/bash ~/anaconda.sh -b -p /opt/conda && \
        rm ~/anaconda.sh && \
        ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# start new shell with conda base env
# ref: https://pythonspeed.com/articles/activate-conda-dockerfile/
RUN echo "conda activate base" >> ~/.bashrc
SHELL ["/bin/bash", "--login", "-c"]

# install torch and tf
RUN conda install -y pytorch torchvision torchaudio pytorch-cuda=11.8 -c pytorch-nightly -c nvidia
RUN conda install -y -c conda-forge tensorflow tensorboard keras gpustat scikit-learn-intelex py3nvml glances

# DO NOT run conda commands after this
RUN conda init bash

# add user for doing sudo
# su - docker_admin -c "sudo adduser $USER sudo"
RUN useradd -m docker_admin
RUN usermod -aG sudo docker_admin
RUN passwd -x -1 docker_admin && passwd -d docker_admin
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# run entry commands
# COPY docker_entry.sh /docker_entry.sh
# RUN chmod +x /docker_entry.sh
# ENTRYPOINT ["bash", "/docker_entry.sh"]