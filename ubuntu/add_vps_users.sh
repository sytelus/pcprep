#!/usr/bin/env bash
# Create the VPS accounts sy_agent, sy_dev and sy_deploy (see vpsman). Each gets
# passwordless sudo and logs in with the same SSH public keys as the account
# that runs this script. prepare_new_vps.sh calls it; to run it alone:
#   sudo bash ubuntu/add_vps_users.sh
# Existing accounts are left unchanged, so reruns are safe. add_user.sh gives
# each account a "Match User" block in sshd_config, which vps_harden.sh reads
# to keep these accounts in its SSH allowlist.
#
# Exit status 2 means your account has no SSH key on this server yet, so no
# account was created; prepare_new_vps.sh then continues without them.
set -euo pipefail
umask 077
export LC_ALL=C

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
(( EUID == 0 )) || die "Run with sudo from your regular account."
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

owner=${SUDO_USER:-}
[[ $owner =~ ^[a-z_][a-z0-9_-]*$ ]] && [[ $(id -u -- "$owner" 2>/dev/null) =~ ^[1-9][0-9]*$ ]] ||
    die "Run with sudo from the regular account whose SSH keys the new accounts should share."
owner_home=$(getent passwd -- "$owner" | cut -d: -f6)

missing=()
for user in sy_agent sy_dev sy_deploy; do
    if id -- "$user" >/dev/null 2>&1; then
        printf 'User %s already exists; leaving it unchanged.\n' "$user"
    else
        missing+=("$user")
    fi
done
(( ${#missing[@]} )) || exit 0

# The keys you log in with live in the files sshd reads for your account
# (AuthorizedKeysFile, normally ~/.ssh/authorized_keys).
[[ -d /run/sshd ]] || install -d -m 0755 /run/sshd
key_files=()
for key_file in $(sshd -T -C "user=$owner,host=localhost,addr=127.0.0.1" |
                  awk '$1 == "authorizedkeysfile" { $1 = ""; print }'); do
    [[ $key_file == none ]] && continue
    key_file=${key_file//\%h/$owner_home}
    key_file=${key_file//\%u/$owner}
    [[ $key_file == /* ]] || key_file="$owner_home/$key_file"
    [[ -f $key_file && ! -L $key_file ]] && key_files+=("$key_file")
done

# Copy plain keys only. A line with options such as from= or command= would
# lose its restriction if copied without them, so it is skipped.
keys=$(mktemp)
trap 'rm -f -- "$keys"' EXIT
skipped=0
for key_file in "${key_files[@]}"; do
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
    done < "$key_file"
done
if [[ ! -s $keys ]]; then
    cat >&2 <<EOF
NOTE: $owner has no SSH key on this server, so ${missing[*]} were not created.
These accounts log in with your SSH key, and vps_harden.sh turns off SSH
passwords, so a key is needed anyway. Add yours from your own computer:
  Windows PowerShell: type \$env:USERPROFILE\\.ssh\\id_ed25519.pub | ssh $owner@<server> "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
  Linux, macOS or Git Bash: ssh-copy-id $owner@<server>
(No key yet? Run ssh-keygen -t ed25519 first.) Then run: sudo bash $script_dir/add_vps_users.sh
EOF
    exit 2
fi
if (( skipped )); then
    printf 'Skipped %d line(s) with options or no plain key; add those keys by hand.\n' "$skipped" >&2
fi

for user in "${missing[@]}"; do
    bash "$script_dir/add_user.sh" "$user" yes "$keys"
done
printf 'Created %s with passwordless sudo and the SSH keys of %s.\n' "${missing[*]}" "$owner"
printf 'Log in with, for example: ssh sy_dev@<server>\n'
