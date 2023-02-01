#!/bin/bash
set -euo pipefail
set -o errexit
set -o errtrace


mkdir -p ~/az_blob # mount point for Azure blob storage

# Authorize access to your storage account and mount our blobstore
# Example: https://github.com/Azure/azure-storage-fuse/blob/main/sampleFileCacheConfig.yaml
# Full Config: https://github.com/Azure/azure-storage-fuse/blob/main/setup/baseConfig.yaml
blobfuse2 mount ~/az_blob --config-file=./azure-mount-config.yaml
