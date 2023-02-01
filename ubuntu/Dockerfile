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


# From min_system.sh
RUN apt-get -y update
RUN apt-get -y install git curl wget xclip xz-utils tar apt-transport-https trash-cli bash-completion
RUN apt-get -y install tlp powertop tlp-rdw inxi procinfo nvidia-prime htop #conky-all #conky-cli
RUN apt-get -y install build-essential cmake libopencv-dev g++ libopenmpi-dev zlib1g-dev
RUN apt-get -y install fortune-mod sl espeak figlet sysvbanner cowsay oneko cmatrix toilet pi xcowsay aview bb rig weather-util ponysay
RUN apt-get -y fslint fdupes locate
# needed for docker
RUN apt-get -y install apt-transport-https ca-certificates curl gnupg lsb-release

# some more stuff
RUN apt-get -y install bzip2 libglib2.0-0 libxext6 libsm6 libxrender1 mercurial subversion
RUN apt-get clean

RUN wget --quiet https://repo.anaconda.com/anaconda/Anaconda3-latest-Linux-x86_64.sh -O ~/anaconda.sh  && \
        /bin/bash ~/anaconda.sh -b -p /opt/conda && \
        rm ~/anaconda.sh && \
        ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# Users might wan t to run:
# echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc

ENV PATH /opt/conda/bin:$PATH

RUN conda install -y pytorch torchvision torchaudio pytorch-cuda=11.8 -c pytorch-nightly -c nvidia
RUN pip install -q tensorflow tensorboard keras
