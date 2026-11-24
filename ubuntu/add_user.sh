#!/usr/bin/env bash
# Create an Ubuntu user. Run on the server from the repository root:
#   sudo bash ubuntu/add_user.sh
#   sudo bash ubuntu/add_user.sh dev yes ./id_ed25519_vps.pub
#   sudo bash ubuntu/add_user.sh guest no ''     # passwd prompts for the password
# The third argument can also be a quoted OpenSSH public key. A key file may
# list several keys, one per line. The script prompts
# for omitted arguments. Press Enter at the key prompt to use password login.
set -euo pipefail
umask 077
export LC_ALL=C

die() { printf '%s\n' "$*" >&2; exit 1; }
usage="Usage: sudo bash $0 [username [yes|no [public-key-file|public-key|'']]]"
if [[ ${1:-} == --help || ${1:-} == -h ]]; then echo "$usage"; exit 0; fi
(( $# <= 3 )) || die "$usage"
(( EUID == 0 )) || die "Run this script with sudo."

username=${1:-}
sudo_answer=${2:-}
key=${3:-}
[[ -n $username ]] || read -rp 'New username: ' username || die "A username is required."
[[ $username =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "Invalid Ubuntu username: $username"
[[ -n $sudo_answer ]] || read -rp 'Allow passwordless sudo? [y/N] ' sudo_answer || die "No sudo choice supplied."
case ${sudo_answer,,} in
    y|yes|true|1) sudo_group=(--groups sudo) ;;
    n|no|false|0|'') sudo_group=() ;;
    *) die "Use yes or no for sudo." ;;
esac
if (( $# < 3 )); then
    IFS= read -rp 'SSH public key or file (Enter for password): ' key || die "No login method supplied."
fi
# A key file may hold several keys, one per line, in authorized_keys format
# without options. Blank lines and comments are ignored.
keys=()
if [[ -n $key ]]; then
    if [[ -f $key ]]; then key=$(< "$key"); fi
    while IFS= read -r line; do
        line=${line%$'\r'}  # Also accept .pub files copied from Windows.
        [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
        read -r key_type key_data _ <<< "$line"
        [[ $key_type =~ ^(ssh-|ecdsa-|sk-) ]] ||
            die "Supply OpenSSH public keys, one per line without options, or the path to a .pub file."
        ssh-keygen -lf - <<< "$key_type $key_data" >/dev/null || die "Invalid SSH public key."
        keys+=("$line")
    done <<< "$key"
    (( ${#keys[@]} )) || die "No SSH public key found."
fi

main=/etc/ssh/sshd_config
hardening=/etc/ssh/sshd_config.d/00-hardening.conf
sudo_rule="/etc/sudoers.d/90-pcprep-$username"
user_home="/home/$username"

# Serialize edits to the shared SSH files. Only a fresh account and home can
# be rolled back safely if the password prompt, config check or reload fails.
exec 9>/run/pcprep-add-user.lock
flock -x 9
[[ ! -e /run/pcprep-vps-pending ]] || die "Confirm the pending VPS access change or wait for rollback before adding a user."
if id "$username" >/dev/null 2>&1; then die "User $username already exists."; fi
[[ ! -e $user_home && ! -L $user_home ]] || die "Home already exists: $user_home"
[[ ! -e $sudo_rule && ! -L $sudo_rule ]] || die "Sudo rule already exists: $sudo_rule"
# A socket-activated Ubuntu server may not have started sshd yet.
[[ -d /run/sshd ]] || install -d -m 0755 /run/sshd
sshd -t
work=$(mktemp -d /etc/ssh/.add-user.XXXXXXXX)
changed_files=()
created=0
sudo_installed=0
reload_attempted=0
cleanup() {
    local status=$? i
    set +e  # Attempt each rollback step even if another one fails.
    if (( status != 0 )); then
        printf 'Setup failed. Rolling back changes for %s.\n' "$username" >&2
        for i in "${!changed_files[@]}"; do
            if [[ -f $work/$i ]]; then mv -f -- "$work/$i" "${changed_files[i]}"
            else rm -f -- "${changed_files[i]}"
            fi
        done
        if (( sudo_installed )); then rm -f -- "$sudo_rule"; fi
        if (( created )); then userdel --remove "$username"; fi
        if (( reload_attempted )); then sshd -t && systemctl reload ssh.service; fi
    fi
    rm -rf -- "$work"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# Start with an unusable password hash until the requested login policy is ready.
useradd --create-home --home-dir "$user_home" --shell /bin/bash --password '*' "${sudo_group[@]}" "$username"
created=1
if (( ${#sudo_group[@]} )); then
    # Give only this user a passwordless rule and test it as that user.
    printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$username" > "$work/sudoers"
    visudo -cf "$work/sudoers" >/dev/null
    sudo_installed=1
    install -m 0440 -o root -g root "$work/sudoers" "$sudo_rule"
    visudo -c >/dev/null
    runuser -u "$username" -- sudo -k -n /usr/bin/true || die "Passwordless sudo failed for $username."
fi

# Check Match rules using the current connection, or the configured SSH port
# when invoked from a console or when sudo removes SSH_CONNECTION.
global=$(sshd -T)
port=$(awk '$1 == "port" { print $2; exit }' <<< "$global")
read -r client_addr _ server_addr server_port <<< "${SSH_CONNECTION:-192.0.2.1 0 192.0.2.2 $port}"
connection="user=$username,host=$client_addr,addr=$client_addr,laddr=$server_addr,lport=$server_port"
effective=$(sshd -T -C "$connection")
# A password must work on its own, even if the server normally requires a key.
accepts_password() {
    grep -Fxq 'passwordauthentication yes' <<< "$1" &&
        grep -Eq '^authenticationmethods( [^ ]+)* (any|password)( |$)' <<< "$1"
}
options=()
if (( ${#keys[@]} )); then
    options=('PubkeyAuthentication yes' 'AuthorizedKeysFile .ssh/authorized_keys'
             'AuthenticationMethods publickey' 'PasswordAuthentication no' 'KbdInteractiveAuthentication no')
elif ! accepts_password "$global" || ! accepts_password "$effective"; then
    # Permit a password by itself for this user, and allow a key added later.
    options=('PasswordAuthentication yes' 'AuthenticationMethods publickey password')
fi

# sshd -T prints one AllowUsers pattern per line. Honor an existing grant,
# including a wildcard or user@host, so its source restriction survives.
lists_user() {
    local directive pattern
    while read -r directive pattern; do
        [[ $directive == allowusers && $username == ${pattern%%@*} ]] && return 0
    done <<< "$1"
    return 1
}

# Add a global entry only if the server already restricts logins with AllowUsers.
# Ubuntu includes *.conf by default. Older standalone configs use the main file.
allow_file=''
if grep -q '^allowusers ' <<< "$global" && ! lists_user "$global"; then
    allow_file=$main
    stock_include='^[[:space:]]*Include[[:space:]=]+[^#]*sshd_config\.d/\*\.conf(["[:space:]#]|$)'
    if [[ -f $hardening ]] || grep -Eiq "$stock_include" "$main"; then
        [[ ! -d ${hardening%/*} ]] || allow_file=$hardening
    fi
fi

for file in "$hardening" "$main"; do
    allow='' block=''
    if [[ $file == "$allow_file" ]]; then allow=$username; fi
    if [[ $file == "$main" ]] && (( ${#options[@]} )); then
        block=$(printf '\nMatch User %s\n' "$username"; printf '    %s\n' "${options[@]}")
    fi
    [[ -n $allow || -n $block ]] || continue

    # Keep global settings first. Insert our block before other Match rules
    # because the first matching value wins. Keep an original for rollback.
    target=$(realpath -- "$file")
    backup="$work/${#changed_files[@]}"
    original=/dev/null
    if [[ -e $target ]]; then
        cp -p -- "$target" "$backup"
        cp -p -- "$target" "$backup.new"
        original=$backup
    fi
    awk -v allow="$allow" -v block="$block" '
        BEGIN { if (allow != "") print "AllowUsers " allow }
        tolower($1) ~ /^match(=|$)/ && block != "" { print block "\n"; block = "" }
        { print }
        END { if (block != "") print block }
    ' "$original" > "$backup.new"
    changed_files+=("$target")
    mv -f -- "$backup.new" "$target"
done

sshd -t
effective=$(sshd -T -C "$connection")
for option in "${options[@]}"; do
    grep -Fxq "${option,,}" <<< "$effective" || die "Another SSH rule overrides '$option' for $username."
done
if [[ -n $allow_file ]] || grep -q '^allowusers ' <<< "$effective"; then
    lists_user "$effective" || die "The SSH allowlist excludes $username. Check the active Include and Match rules."
fi

# An idle, socket-activated sshd reads the new files when it starts.
if (( ${#changed_files[@]} )); then
    service_state=$(systemctl show --property=ActiveState --value ssh.service)
    if [[ $service_state == active || $service_state == reloading ]]; then
        reload_attempted=1
        systemctl reload ssh.service
    fi
fi

# Enable the chosen credential once SSH and sudo have passed validation.
if (( ${#keys[@]} )); then
    # Write as the account owner, including when /etc/skel supplies .ssh.
    runuser -u "$username" -- sh -ec '
        cd "$1"
        umask 077
        install -d -m 0700 .ssh
        cat > .ssh/authorized_keys
        chmod 0600 .ssh/authorized_keys
    ' sh "$user_home" < <(printf '%s\n' "${keys[@]}")
else
    passwd "$username"
fi
printf 'Created user %s.\n' "$username"
