# NVIDIA Container Toolkit
# without this, docker will not see GPUs!

# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#installation-guide

distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
      && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
      && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update

sudo apt-get install -y nvidia-docker2

# You might get prompted for overwriting the file /etc/docker/daemon.json.
# Say no, press D and append lines manually later that might look like below:

#  sudo nano /etc/docker/daemon.json

#    "runtimes": {
#       "nvidia": {
#          "path": "nvidia-container-runtime",
#          "runtimeArgs": []
#       }
#    }


sudo systemctl restart docker