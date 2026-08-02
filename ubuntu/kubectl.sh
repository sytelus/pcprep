#!/usr/bin/env bash
set -Eeuo pipefail

# Official pkgs.k8s.io repository. Override the minor only when the cluster's
# supported skew requires it; kubectl must remain within one minor of the server.
KUBERNETES_MINOR=${KUBERNETES_MINOR:-v1.36}
[[ $KUBERNETES_MINOR =~ ^v[0-9]+\.[0-9]+$ ]] \
  || { echo "KUBERNETES_MINOR must look like v1.36" >&2; exit 2; }

sudo -v
for cmd in curl gpg; do command -v "$cmd" >/dev/null 2>&1 || { echo "Missing $cmd" >&2; exit 1; }; done
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -d -m 0755 /etc/apt/keyrings

KEYRING=/etc/apt/keyrings/kubernetes-apt-keyring.gpg
LIST=/etc/apt/sources.list.d/kubernetes.list
KEY_TMP=$(mktemp)
RING_TMP=$(mktemp)
LIST_TMP=$(mktemp)
trap 'rm -f -- "$KEY_TMP" "$RING_TMP" "$LIST_TMP"' EXIT
rm -f -- "$RING_TMP"

curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/deb/Release.key" -o "$KEY_TMP"
gpg --batch --dearmor --output "$RING_TMP" "$KEY_TMP"
gpg --batch --show-keys "$RING_TMP" >/dev/null
printf 'deb [signed-by=%s] https://pkgs.k8s.io/core:/stable:/%s/deb/ /\n' \
  "$KEYRING" "$KUBERNETES_MINOR" > "$LIST_TMP"

sudo install -m 0644 "$RING_TMP" "$KEYRING"
sudo install -m 0644 "$LIST_TMP" "$LIST"
sudo apt-get update
sudo apt-get install -y kubectl
kubectl version --client
