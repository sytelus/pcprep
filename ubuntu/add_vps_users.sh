#!/usr/bin/env bash
# Create the VPS accounts sy_agent, sy_dev and sy_deploy (see vpsman). Each gets
# passwordless sudo and logs in with the same SSH public keys as the account
# that runs this script. prepare_new_vps.sh calls it; to run it alone:
#   sudo bash ubuntu/add_vps_users.sh
# Existing accounts are left unchanged, so reruns are safe. add_user.sh gives
# each account a "Match User" block in sshd_config, which vps_harden.sh reads
# to keep these accounts in its SSH allowlist.
set -euo pipefail
umask 077
export LC_ALL=C

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
(( EUID == 0 )) || die "Run with sudo from your regular account."
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
users=(sy_agent sy_dev sy_deploy)

owner=${SUDO_USER:-}
[[ $owner =~ ^[a-z_][a-z0-9_-]*$ ]] && [[ $(id -u -- "$owner" 2>/dev/null) =~ ^[1-9][0-9]*$ ]] ||
    die "Run with sudo from the regular account whose SSH keys the new accounts should share."
owner_home=$(getent passwd -- "$owner" | cut -d: -f6)
source_keys="$owner_home/.ssh/authorized_keys"
[[ -f $source_keys && ! -L $source_keys ]] ||
    die "$source_keys is missing. Add your SSH public key to $owner first."

# Copy plain keys only. A line with options such as from= or command= would
# lose its restriction if copied without them, so it is skipped.
keys=$(mktemp)
trap 'rm -f -- "$keys"' EXIT
skipped=0
while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    read -r key_type key_data _ <<< "$line"
    if [[ $key_type =~ ^(ssh-|ecdsa-|sk-) ]] &&
        ssh-keygen -lf - <<< "$key_type $key_data" >/dev/null 2>&1; then
        printf '%s\n' "$line" >> "$keys"
    else
        skipped=$((skipped + 1))
    fi
done < "$source_keys"
[[ -s $keys ]] || die "No plain SSH public key found in $source_keys."
if (( skipped )); then
    printf 'Skipped %d line(s) of %s that have options or are not plain keys.\n' \
        "$skipped" "$source_keys" >&2
    printf 'Add those keys to the new accounts by hand so their restrictions are kept.\n' >&2
fi

created=()
for user in "${users[@]}"; do
    if id -- "$user" >/dev/null 2>&1; then
        printf 'User %s already exists; leaving it unchanged.\n' "$user"
        continue
    fi
    bash "$script_dir/add_user.sh" "$user" yes "$keys"
    created+=("$user")
done

if (( ${#created[@]} )); then
    printf 'Created %s with passwordless sudo and the SSH keys of %s.\n' "${created[*]}" "$owner"
    printf 'Log in with, for example: ssh sy_dev@<server>\n'
fi
