#!/usr/bin/env bash
# Run the cpu-devbox container interactively.
# Usage: ./run.sh [docker run options...]
#   Examples:
#     ./run.sh                          # Run interactively
#     ./run.sh -v "$PWD:/workspace"     # Mount current directory
#     ./run.sh -p 8888:8888             # Expose Jupyter port
#     ./run.sh -c "python script.py"    # Run a command
set -euo pipefail

IMAGE="${IMAGE:-cpu-devbox}"
TAG="${TAG:-local}"

# Additional docker args can be passed via RUN_ARGS env or CLI arguments.
RUN_ARGS=()
if [[ -n "${RUN_EXTRA_ARGS:-}" ]]; then
    # shellcheck disable=SC2206
    RUN_ARGS+=(${RUN_EXTRA_ARGS})
fi

# Collect all arguments
for arg in "$@"; do
    RUN_ARGS+=("$arg")
done

# Build docker run command
DOCKER_CMD=(docker run --rm -it)

# Add memory/IPC settings (useful for ML workloads)
DOCKER_CMD+=(
    --ipc=host
    --ulimit memlock=-1
    --ulimit stack=67108864
)

# Add user-provided arguments and image
if [[ ${#RUN_ARGS[@]} -gt 0 ]]; then
    DOCKER_CMD+=("${RUN_ARGS[@]}")
fi
DOCKER_CMD+=("${IMAGE}:${TAG}")

echo ">> Running ${IMAGE}:${TAG} interactively..."
exec "${DOCKER_CMD[@]}"
