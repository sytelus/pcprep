#!/usr/bin/env bash
set -Eeuo pipefail

# Keep a working installation, but do not let a stale wrong-architecture binary
# (commonly ~/.azure/bin/azcopy on arm64 hosts) block repair on a rerun.
if command -v azcopy >/dev/null 2>&1 && azcopy --version >/dev/null 2>&1; then
    echo "AzCopy is already installed at $(command -v azcopy)"
    exit 0
fi

# Determine system architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    DOWNLOAD_URL="https://aka.ms/downloadazcopy-v10-linux"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    DOWNLOAD_URL="https://aka.ms/downloadazcopy-v10-linux-arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Download AzCopy tar file
echo "Downloading AzCopy for $ARCH..."
tmpdir=$(mktemp -d)
trap 'rm -rf -- "$tmpdir"' EXIT
archive="$tmpdir/azcopy.tar.gz"
curl -fL --retry 3 -o "$archive" "$DOWNLOAD_URL"

# Extract AzCopy
echo "Extracting AzCopy..."
tar -xzf "$archive" -C "$tmpdir"
azcopy_binary=$(find "$tmpdir" -mindepth 2 -maxdepth 2 -type f -name azcopy -print -quit)
[ -n "$azcopy_binary" ] || { echo "Downloaded archive did not contain AzCopy." >&2; exit 1; }

# Install AzCopy without exposing archive paths or cleanup globs in the checkout.
echo "Installing AzCopy..."
sudo install -m 0755 -- "$azcopy_binary" /usr/local/bin/azcopy

# On arm arch like in Lambda GH200s, wrong azcopy exist in ~/.azure/bin
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    mkdir -p "$HOME/.azure/bin"
    install -m 0755 -- /usr/local/bin/azcopy "$HOME/.azure/bin/azcopy"
fi

# Verify installation
if command -v azcopy &> /dev/null; then
    echo "AzCopy has been successfully installed!"
    azcopy --version
else
    echo "Installation failed!"
    exit 1
fi
