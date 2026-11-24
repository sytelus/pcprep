#!/usr/bin/env bash
# Prepare an Ubuntu VPS for web hosting and agent development. Run as your
# regular user. This skips CUDA, PyTorch, Azure tools and workstation-only
# packages, adds the sy_agent, sy_dev and sy_deploy accounts first, and
# upgrades all installed packages at the end.
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export INSTALL_CUDA=0 INSTALL_PYTORCH=0 INSTALL_AZURE_CLI=0 INSTALL_WORKSTATION_PACKAGES=0
if [[ $(id -u) == 0 ]]; then
    echo "Run prepare_new_vps.sh as your regular user, without sudo." >&2
    exit 1
fi
# Status 2: no SSH key on this server yet. Set up everything else anyway.
users_status=0
sudo bash -- "$script_dir/add_vps_users.sh" || users_status=$?
(( users_status == 0 || users_status == 2 )) || exit "$users_status"
bash -- "$script_dir/prepare_new_box.sh" "$@"

# A provider image is often weeks behind, and automatic updates later install
# only security fixes, so upgrade everything once. Keep config files that were
# changed on this server, such as sshd_config.
if [[ ${NO_NET:-0} != 1 ]]; then
    echo "Upgrading the installed packages."
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -y \
        -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold full-upgrade
    if [[ -f /run/reboot-required ]]; then
        echo "Reboot to finish the upgrade: sudo reboot"
    fi
fi
if (( users_status == 2 )); then
    me=$(id -un)
    cat >&2 <<EOF

NOTE: sy_agent, sy_dev and sy_deploy were not created because $me has no SSH
key on this server. Add your key from your own computer:
  Windows PowerShell: type \$env:USERPROFILE\\.ssh\\id_ed25519.pub | ssh $me@<server> "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
  Linux, macOS or Git Bash: ssh-copy-id $me@<server>
Then run: sudo bash $script_dir/add_vps_users.sh
EOF
fi
