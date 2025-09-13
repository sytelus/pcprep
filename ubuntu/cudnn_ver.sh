#!/bin/bash

set -o xtrace


# Find the directory where nvcc is located
nvcc_path=$(which nvcc)
if [ -z "$nvcc_path" ]; then
    echo "nvcc not found in PATH"
    exit 1
fi

# Extract the directory from the nvcc path
nvcc_dir=$(dirname "$nvcc_path")

# Find the cudnn.h file
cudnn_header=$(find "$nvcc_dir" -name cudnn.h)

if [ -z "$cudnn_header" ]; then
    echo "cudnn.h not found in the nvcc directory"
    exit 1
fi

# Extract cuDNN version from the header file
cudnn_version=$(grep "#define CUDNN_MAJOR" "$cudnn_header" | awk '{print $3}')
cudnn_minor=$(grep "#define CUDNN_MINOR" "$cudnn_header" | awk '{print $3}')
cudnn_patchlevel=$(grep "#define CUDNN_PATCHLEVEL" "$cudnn_header" | awk '{print $3}')

if [ -z "$cudnn_version" ]; then
    echo "Could not extract cuDNN version from the header file"
    exit 1
fi

# Output the cuDNN version
echo "cuDNN version: $cudnn_version.$cudnn_minor.$cudnn_patchlevel"
