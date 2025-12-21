#!/bin/bash

set -eu -o pipefail  # fail if any command failes, -o xtrace to log all commands, -o xtrace

# 1. Update package lists ONLY (do not upgrade installed packages)
echo "Updating package lists..."
sudo apt update

# 2. Install ONLY the build tools needed for Cargo
# (build-essential, pkg-config, and libssl-dev are required to compile Zellij)
echo "Installing build dependencies..."
sudo apt install -y curl build-essential pkg-config libssl-dev

# 3. Install Rust via rustup
echo "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# 4. Activate Rust for this script
source "$HOME/.cargo/env"


