curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

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