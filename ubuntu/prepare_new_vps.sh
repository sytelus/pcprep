#!/usr/bin/env bash
# Prepare an Ubuntu VPS for web hosting and agent development. Run as your
# regular user. This skips CUDA, PyTorch, Azure tools and workstation-only
# packages, and adds the sy_agent, sy_dev and sy_deploy accounts first.
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export INSTALL_CUDA=0 INSTALL_PYTORCH=0 INSTALL_AZURE_CLI=0 INSTALL_WORKSTATION_PACKAGES=0
if [[ $(id -u) == 0 ]]; then
    echo "Run prepare_new_vps.sh as your regular user, without sudo." >&2
    exit 1
fi
sudo bash -- "$script_dir/add_vps_users.sh"
exec bash -- "$script_dir/prepare_new_box.sh" "$@"
