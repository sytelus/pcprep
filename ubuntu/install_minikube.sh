#!/usr/bin/env bash
set -Eeuo pipefail

# Pinned release and checksums from the upstream v1.38.1 release page.
MINIKUBE_VERSION=${MINIKUBE_VERSION:-v1.38.1}
case $(uname -m) in
  x86_64|amd64)
    MINIKUBE_ARCH=amd64
    EXPECTED_SHA256=099477eaf248bcb5bcea8ce78a2898e93ac01461c35189da1848c3de82ecd22e
    ;;
  aarch64|arm64)
    MINIKUBE_ARCH=arm64
    EXPECTED_SHA256=a0b8a1ebfc8c07a247271d8df98ac0ddd7c8c855b601d402463e2e50c08c6bab
    ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
[[ $MINIKUBE_VERSION == v1.38.1 ]] \
  || { echo "No reviewed checksum is recorded for MINIKUBE_VERSION=$MINIKUBE_VERSION" >&2; exit 2; }

for cmd in curl sha256sum; do command -v "$cmd" >/dev/null 2>&1 || { echo "Missing $cmd" >&2; exit 1; }; done
TMP=$(mktemp)
trap 'rm -f -- "$TMP"' EXIT
URL="https://github.com/kubernetes/minikube/releases/download/${MINIKUBE_VERSION}/minikube-linux-${MINIKUBE_ARCH}"
curl -fL --retry 3 --proto '=https' --tlsv1.2 "$URL" -o "$TMP"
printf '%s  %s\n' "$EXPECTED_SHA256" "$TMP" | sha256sum --check --status \
  || { echo "Minikube checksum verification failed" >&2; exit 1; }
sudo install -m 0755 "$TMP" /usr/local/bin/minikube
[[ $(/usr/local/bin/minikube version --short) == "$MINIKUBE_VERSION" ]] \
  || { echo "Installed Minikube version did not match $MINIKUBE_VERSION" >&2; exit 1; }
echo "Installed and verified Minikube $MINIKUBE_VERSION ($MINIKUBE_ARCH)"
