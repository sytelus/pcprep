#!/usr/bin/env bash
# Install an NVIDIA CUDA toolkit without installing or replacing GPU drivers.
# Ubuntu 22.04, 24.04, and 26.04 are supported on amd64 and arm64/SBSA.

set -Eeuo pipefail

CUDA_VERSION=${CUDA_VERSION:-}
OS_RELEASE_FILE=${PCPREP_OS_RELEASE_FILE:-/etc/os-release}
ARCH=${PCPREP_ARCH:-$(uname -m)}
MODE=install

usage() {
    cat <<'EOF'
Usage: sudo CUDA_VERSION=13.3 bash install_cuda.sh
       bash install_cuda.sh --check

--check verifies that the matching NVIDIA repository and toolkit package exist
without changing the system. CUDA_VERSION defaults to 13.2 on Ubuntu 22.04 and
24.04, and 13.3 on Ubuntu 26.04, following NVIDIA's native repositories.
EOF
}

if [ "${1:-}" = "--check" ]; then
    MODE=check
    shift
fi
if [ "$#" -ne 0 ]; then
    usage >&2
    exit 2
fi

[ -r "$OS_RELEASE_FILE" ] || {
    echo "Unable to read OS release metadata: $OS_RELEASE_FILE" >&2
    exit 1
}
# shellcheck disable=SC1090
. "$OS_RELEASE_FILE"

if [ -z "$CUDA_VERSION" ]; then
    case ${VERSION_ID:-} in
        26.04) CUDA_VERSION=13.3 ;;
        *) CUDA_VERSION=13.2 ;;
    esac
fi
[[ $CUDA_VERSION =~ ^[0-9]+\.[0-9]+$ ]] || {
    echo "CUDA_VERSION must have major.minor form (for example, 13.3)." >&2
    exit 2
}

if [ "${ID:-}" != "ubuntu" ]; then
    echo "This installer supports Ubuntu only; detected ${PRETTY_NAME:-unknown}." >&2
    exit 1
fi
case ${VERSION_ID:-} in
    22.04|24.04|26.04) ;;
    *)
        echo "Unsupported Ubuntu release: ${VERSION_ID:-unknown}." >&2
        echo "Supported releases: 22.04, 24.04, and 26.04." >&2
        exit 1
        ;;
esac

case $ARCH in
    x86_64|amd64) CUDA_ARCH=x86_64 ;;
    aarch64|arm64) CUDA_ARCH=sbsa ;;
    *)
        echo "Unsupported architecture: $ARCH (expected amd64 or arm64)." >&2
        exit 1
        ;;
esac

DISTRO="ubuntu${VERSION_ID//./}"
CUDA_VERSION_DASH=${CUDA_VERSION//./-}
CUDA_META="cuda-toolkit-${CUDA_VERSION_DASH}"
CUDA_ROOT="/usr/local/cuda-${CUDA_VERSION}"
CUDA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/${CUDA_ARCH}"
CUDA_KEYRING_URL="${CUDA_REPO_URL}/cuda-keyring_1.1-1_all.deb"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Required command not found: $1" >&2
        exit 1
    }
}

check_repository() {
    echo "Checking ${CUDA_REPO_URL} for ${CUDA_META}..."
    curl -fsSI "$CUDA_KEYRING_URL" >/dev/null
    curl -fsSL "${CUDA_REPO_URL}/Packages.gz" \
        | gzip -dc \
        | grep -Fx "Package: ${CUDA_META}" >/dev/null
}

require_command curl
require_command gzip
require_command grep

if [ "$MODE" = check ]; then
    check_repository
    echo "CUDA repository check passed for Ubuntu $VERSION_ID, $ARCH, toolkit $CUDA_VERSION."
    exit 0
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo CUDA_VERSION=$CUDA_VERSION bash $0" >&2
    exit 1
fi
require_command apt-cache
require_command apt-get
require_command dpkg

tmpdir=$(mktemp -d)
trap 'rm -rf -- "$tmpdir"' EXIT

check_repository
echo "Installing NVIDIA's repository keyring for ${DISTRO}/${CUDA_ARCH}..."
curl -fsSL "$CUDA_KEYRING_URL" -o "$tmpdir/cuda-keyring.deb"
dpkg --force-confnew -i "$tmpdir/cuda-keyring.deb"

apt-get update
if ! apt-cache policy "$CUDA_META" 2>/dev/null \
    | awk '/Candidate:/ {print $2}' \
    | grep -vq '(none)'; then
    echo "NVIDIA repository does not offer $CUDA_META for ${DISTRO}/${CUDA_ARCH}." >&2
    exit 1
fi

echo "Installing $CUDA_META (toolkit only; NVIDIA drivers are untouched)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y "$CUDA_META"

if [ ! -x "$CUDA_ROOT/bin/nvcc" ]; then
    echo "Expected nvcc was not installed at $CUDA_ROOT/bin/nvcc." >&2
    exit 2
fi
"$CUDA_ROOT/bin/nvcc" --version

helper="/usr/local/bin/use-cuda${CUDA_VERSION}"
cat > "$helper" <<EOF
#!/usr/bin/env bash
export CUDA_HOME="$CUDA_ROOT"
export PATH="\${CUDA_HOME}/bin:\${PATH}"
export LD_LIBRARY_PATH="\${CUDA_HOME}/lib64\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
echo "Using CUDA at \${CUDA_HOME}"
nvcc --version 2>/dev/null || true
EOF
chmod 0755 "$helper"
ln -sfn "$helper" /usr/local/bin/use-cuda

echo "CUDA Toolkit $CUDA_VERSION installed; NVIDIA driver packages were not modified."
echo "Run 'source $helper' (or 'source /usr/local/bin/use-cuda') in a shell to use it."
