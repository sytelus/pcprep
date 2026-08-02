#!/usr/bin/env bash
set -Eeuo pipefail

# The upstream convenience installer remains tracked under the deferred
# supply-chain TODO; this script no longer opens a blocking newgrp subshell.
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

getent group docker >/dev/null 2>&1 || sudo groupadd docker
sudo usermod -aG docker "$USER"
if [[ -d $HOME/.docker ]]; then
  sudo chown -R "$USER":"$(id -gn)" "$HOME/.docker"
  chmod -R u+rwX,g+rwX "$HOME/.docker"
fi
sudo systemctl enable --now containerd.service docker.service
sudo docker version >/dev/null

echo "Docker installed and verified with sudo. Group membership was updated."
echo "Log out and back in (or start a new login shell) before using Docker without sudo."
