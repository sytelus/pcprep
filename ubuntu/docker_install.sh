# this should also work
# curl https://get.docker.com | sh \
#   && sudo systemctl --now enable docker

# docker pre-req should be installed by min_system.sh
sudo apt-get install docker-ce docker-ce-cli containerd.io
# setup so docker command doesn't need sudo
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
# make sure .docker dir has access
sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
sudo chmod g+rwx "$HOME/.docker" -R
# run docker service
sudo systemctl enable docker.service
sudo systemctl enable containerd.service