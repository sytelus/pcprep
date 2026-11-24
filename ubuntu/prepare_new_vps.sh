#!/usr/bin/env bash
# Run the Ubuntu bootstrap with CUDA, PyTorch, and Azure tools disabled.
export INSTALL_CUDA=0 INSTALL_PYTORCH=0 INSTALL_AZURE_CLI=0
exec bash -- "$(dirname -- "${BASH_SOURCE[0]}")/prepare_new_box.sh" "$@"
