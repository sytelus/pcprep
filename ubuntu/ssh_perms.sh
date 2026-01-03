#!/bin/bash

# rerun this file any time to remove passkeys and setup correct perms

# Create .ssh directory if it doesn't exist and set permissions
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

shopt -s nullglob

is_private_key() {
    local file="$1"
    head -n 1 "$file" 2>/dev/null | grep -qE '^-----BEGIN .*PRIVATE KEY-----$'
}

set_private_key_permissions() {
    local private_key="$1"

    if ssh-keygen -p -f "$private_key" -N ""; then
        echo "Removed passphrase for $private_key"
    else
        echo "Warning: failed to update $private_key (passphrase may remain)"
    fi

    chmod 600 "$private_key"
    echo "Set 600 for $private_key"
}

set_public_key_permissions() {
    local public_key="$1"
    chmod 644 "$public_key"
    echo "Set 644 for $public_key"
}

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
