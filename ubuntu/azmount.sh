#!/bin/bash
set -euo pipefail
set -o errexit
set -o errtrace


mkdir -p ~/azblob # mount point for Azure blob storage
mkdir -p /tmp/blobfuse # cache location for Azure blob storage

# Authorize access to your storage account and mount our blobstore
# Example: https://github.com/Azure/azure-storage-fuse/blob/main/sampleFileCacheConfig.yaml
# Full Config: https://github.com/Azure/azure-storage-fuse/blob/main/setup/baseConfig.yaml
# sudo is required
sudo blobfuse2 mount ~/azblob --config-file=./azure-mount-config.yaml
