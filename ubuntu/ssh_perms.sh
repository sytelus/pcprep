#!/bin/bash

set -Eeuo pipefail

# Re-run this file any time to normalize ~/.ssh permissions.  By default it
# does not modify private-key passphrases; set
# REMOVE_SSH_KEY_PASSPHRASES=1 to opt into stripping them.
REMOVE_SSH_KEY_PASSPHRASES="${REMOVE_SSH_KEY_PASSPHRASES:-0}"

# Create .ssh directory if it doesn't exist and set permissions
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

shopt -s nullglob

bool_is_true() {
    case "${1:-0}" in
        1|y|Y|yes|YES|true|TRUE|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

set_ssh_config_permissions() {
    local ssh_config="$HOME/.ssh/config"

    if [ -f "$ssh_config" ]; then
        chmod 600 "$ssh_config"
        echo "Set 600 for $ssh_config"
    fi
}

is_private_key() {
    local file="$1"
    head -n 1 "$file" 2>/dev/null | grep -qE '^-----BEGIN .*PRIVATE KEY-----$'
}

set_private_key_permissions() {
    local private_key="$1"

    if bool_is_true "$REMOVE_SSH_KEY_PASSPHRASES"; then
        if ssh-keygen -p -f "$private_key" -N ""; then
            echo "Removed passphrase for $private_key"
        else
            echo "Warning: failed to update $private_key (passphrase may remain)"
        fi
    fi

    chmod 600 "$private_key"
    echo "Set 600 for $private_key"
}

set_public_key_permissions() {
    local public_key="$1"
    chmod 644 "$public_key"
    echo "Set 644 for $public_key"
}

# Set permissions for SSH config
set_ssh_config_permissions

# Set permissions for public keys
for public_key in "$HOME/.ssh/"*.pub; do
    [ -f "$public_key" ] && set_public_key_permissions "$public_key"
done

# Set permissions for private keys
for private_key in "$HOME/.ssh/"*; do
    [ -f "$private_key" ] || continue
    case "$private_key" in
        *.pub) continue ;;
    esac

    if is_private_key "$private_key"; then
        set_private_key_permissions "$private_key"
    fi
done

echo "SSH directory and key permissions have been set up."
