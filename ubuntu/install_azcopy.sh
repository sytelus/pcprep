#!/bin/bash
#fail if any errors
set -e
set -o xtrace

#!/bin/bash

# Check if AzCopy is already installed
if command -v azcopy &> /dev/null; then
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
curl -L -o azcopy.tar.gz "$DOWNLOAD_URL"

# Extract AzCopy
echo "Extracting AzCopy..."
tar -xzf azcopy.tar.gz

# Move AzCopy to /usr/local/bin
echo "Installing AzCopy..."
sudo mv azcopy_linux_*/azcopy /usr/local/bin/azcopy

# Clean up downloaded files
rm -rf azcopy_linux_* azcopy.tar.gz

# Verify installation
if command -v azcopy &> /dev/null; then
    echo "AzCopy has been successfully installed!"
    azcopy --version
else
    echo "Installation failed!"
    exit 1
fi
