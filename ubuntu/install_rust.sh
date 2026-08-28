#!/usr/bin/env bash
set -Eeuo pipefail

# 1. Update package lists ONLY (do not upgrade installed packages)
echo "Updating package lists..."
sudo apt-get update

# 2. Install ONLY the build tools needed for Cargo
# (build-essential, pkg-config, and libssl-dev are required to compile Zellij)
echo "Installing build dependencies..."
sudo apt-get install -y --no-install-recommends curl build-essential pkg-config libssl-dev

# 3. Install Rust via rustup only when it is not already present. This keeps a
# rerun from downloading the installer and replaying an existing configuration.
if [ -x "$HOME/.cargo/bin/rustup" ]; then
    echo "rustup is already installed; preserving the existing toolchains."
else
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# 4. Activate Rust for this script
# shellcheck disable=SC1091
source "$HOME/.cargo/env"
rustc --version
cargo --version
