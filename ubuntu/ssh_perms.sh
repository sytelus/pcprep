#!/bin/bash

# Create .ssh directory if it doesn't exist and set permissions
mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Function to set permissions for a key pair
set_key_permissions() {
    local private_key="$1"
    local public_key="${private_key}.pub"

    [ -f "$private_key" ] && chmod 600 "$private_key" && echo "Set 600 for $private_key" || echo "Warning: $private_key not found"
    [ -f "$public_key" ] && chmod 644 "$public_key" && echo "Set 644 for $public_key" || echo "Warning: $public_key not found"
}

# Set permissions for valid key pairs in .ssh directory
for private_key in ~/.ssh/*; do
    [[ -f "$private_key" && ! "$private_key" == *.pub && -f "${private_key}.pub" ]] && set_key_permissions "$private_key"
done

echo "SSH directory and key permissions have been set up."