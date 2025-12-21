#!/bin/bash

set -eu -o pipefail  # fail if any command failes, -o xtrace to log all commands, -o xtrace

# 1. Update system and install build dependencies
# (build-essential is often needed by Cargo to compile dependencies)
echo "Installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl build-essential pkg-config libssl-dev

# 2. Remove any old system-level Rust/Cargo to avoid version conflicts
echo "Removing old system Rust/Cargo..."
sudo apt remove -y cargo rustc
sudo apt autoremove -y

# 3. Install the latest stable Rust toolchain (Non-interactive mode)
echo "Installing Rust via rustup..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# 4. Configure the current shell session to use the new Cargo immediately
# (This loads the path for the current run so the script doesn't fail)
source "$HOME/.cargo/env"

