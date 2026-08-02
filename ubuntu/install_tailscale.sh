#!/usr/bin/env bash
set -Eeuo pipefail

[[ -r /etc/os-release ]] || { echo "/etc/os-release is required" >&2; exit 1; }
# shellcheck disable=SC1091
. /etc/os-release
case ${ID:-} in ubuntu|debian) ;; *) echo "Supported distributions: Ubuntu and Debian" >&2; exit 1 ;; esac
CODENAME=${VERSION_CODENAME:-}
[[ $CODENAME =~ ^[a-z0-9.-]+$ ]] || { echo "Invalid or missing VERSION_CODENAME" >&2; exit 1; }
for cmd in curl gpg; do command -v "$cmd" >/dev/null 2>&1 || { echo "Missing $cmd" >&2; exit 1; }; done

sudo -v
sudo install -d -m 0755 /usr/share/keyrings
KEY_URL="https://pkgs.tailscale.com/stable/${ID}/${CODENAME}.noarmor.gpg"
LIST_URL="https://pkgs.tailscale.com/stable/${ID}/${CODENAME}.tailscale-keyring.list"
KEY_TMP=$(mktemp)
LIST_TMP=$(mktemp)
trap 'rm -f -- "$KEY_TMP" "$LIST_TMP"' EXIT
curl -fsSL --proto '=https' --tlsv1.2 "$KEY_URL" -o "$KEY_TMP"
curl -fsSL --proto '=https' --tlsv1.2 "$LIST_URL" -o "$LIST_TMP"
gpg --batch --show-keys "$KEY_TMP" >/dev/null
grep -q 'signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg' "$LIST_TMP" \
  || { echo "Unexpected Tailscale repository definition" >&2; exit 1; }
sudo install -m 0644 "$KEY_TMP" /usr/share/keyrings/tailscale-archive-keyring.gpg
sudo install -m 0644 "$LIST_TMP" /etc/apt/sources.list.d/tailscale.list
sudo apt-get update
sudo apt-get install -y tailscale
tailscale version
echo "Tailscale installed. Run 'sudo tailscale up' interactively to authenticate."
