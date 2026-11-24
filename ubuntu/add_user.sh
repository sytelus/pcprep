#!/usr/bin/env bash
# Create an Ubuntu user. Run on the server from the repository root:
#   sudo bash ubuntu/add_user.sh
#   sudo bash ubuntu/add_user.sh dev yes ./id_ed25519_vps.pub
#   sudo bash ubuntu/add_user.sh guest no ''     # passwd prompts for the password
# The third argument can also be a quoted OpenSSH public key. The script prompts
# for omitted arguments. Press Enter at the key prompt to use password login.
# If using vps_setup.sh, run it first. It sets the initial SSH allowlist.
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
    y|yes|true|1) grant_sudo=1 ;;
    n|no|false|0|'') grant_sudo=0 ;;
    *) die "Use yes or no for sudo." ;;
esac
if (( $# < 3 )); then
    IFS= read -rp 'SSH public key or file (Enter for password): ' key || die "No login method supplied."
fi
if [[ -n $key ]]; then
    if [[ -f $key ]]; then key=$(< "$key"); fi
    key=${key%$'\r'}  # Also accept .pub files copied from Windows.
    read -r key_type key_data _ <<< "$key"
    [[ $key != *$'\n'* && $key_type =~ ^(ssh-|ecdsa-|sk-) ]] &&
        ssh-keygen -lf - <<< "$key_type $key_data" >/dev/null || die "Supply one valid OpenSSH public key or its .pub file."
fi

main=/etc/ssh/sshd_config
hardening=/etc/ssh/sshd_config.d/00-hardening.conf
configs=("$main")
if [[ -f $hardening ]]; then configs=("$hardening" "$main"); fi
sudo_rule="/etc/sudoers.d/90-pcprep-$username"
user_home="/home/$username"

# Serialize edits to the shared SSH files. Only a fresh account and home can
# be rolled back safely if the password prompt, config check or reload fails.
exec 9>/run/pcprep-add-user.lock
flock -x 9
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
        for i in "${!changed_files[@]}"; do mv -f -- "$work/$i" "${changed_files[i]}"; done
        if (( sudo_installed )); then rm -f -- "$sudo_rule"; fi
        if (( created )); then userdel --remove "$username"; fi
        if (( reload_attempted )); then sshd -t && systemctl reload ssh.service; fi
    fi
    rm -rf -- "$work"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# An unusable password hash keeps the account available for public-key SSH.
useradd --create-home --home-dir "$user_home" --shell /bin/bash --password '*' "$username"
created=1
if (( grant_sudo )); then
    # Give only this user a passwordless rule and test it as that user.
    printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$username" > "$work/sudoers"
    visudo -cf "$work/sudoers" >/dev/null
    sudo_installed=1
    install -m 0440 -o root -g root "$work/sudoers" "$sudo_rule"
    visudo -c >/dev/null
    usermod -aG sudo "$username"
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
if [[ -n $key ]]; then
    options=('PubkeyAuthentication yes' 'AuthorizedKeysFile .ssh/authorized_keys'
             'AuthenticationMethods publickey' 'PasswordAuthentication no' 'KbdInteractiveAuthentication no')
elif ! accepts_password "$global" || ! accepts_password "$effective"; then
    # Permit a password by itself for this user, and allow a key added later.
    options=('PasswordAuthentication yes' 'AuthenticationMethods publickey password')
fi

# Extend an existing global allowlist. Creating one on an unrestricted server
# would lock out its other users. OpenSSH combines multiple AllowUsers lines.
allow_file=''
has_user="^allowusers( [^ ]+)* $username( |$)"
if grep -q '^allowusers ' <<< "$global" && ! grep -Eq "$has_user" <<< "$global"; then
    # Prefer the hardening drop-in. vps_setup.sh keeps its list in the main file.
    allow_file=$(awk '
        FNR == 1 { in_match = 0 }
        tolower($1) ~ /^match(=|$)/ { in_match = 1 }
        !in_match && tolower($1) ~ /^allowusers(=|$)/ { print FILENAME; exit }
    ' "${configs[@]}")
    allow_file=${allow_file:-$main}  # A global restriction in another Include.
fi

for file in "${configs[@]}"; do
    allow='' block=''
    if [[ $file == "$allow_file" ]]; then allow=$username; fi
    if [[ $file == "$main" ]] && (( ${#options[@]} )); then
        block=$(printf '\nMatch User %s\n' "$username"; printf '    %s\n' "${options[@]}")
    fi
    [[ -n $allow || -n $block ]] || continue

    # Keep global settings first. Insert our block before other Match rules
    # because the first matching value wins. Keep an original for rollback.
    target=$(realpath -e -- "$file")
    backup="$work/${#changed_files[@]}"
    cp -p -- "$target" "$backup"
    cp -p -- "$target" "$backup.new"
    awk -v allow="$allow" -v block="$block" '
        BEGIN { if (allow != "") print "AllowUsers " allow }
        tolower($1) ~ /^match(=|$)/ && block != "" { print block "\n"; block = "" }
        { print }
        END { if (block != "") print block }
    ' "$backup" > "$backup.new"
    changed_files+=("$target")
    mv -f -- "$backup.new" "$target"
done

sshd -t
effective=$(sshd -T -C "$connection")
for option in "${options[@]}"; do
    grep -Fxq "${option,,}" <<< "$effective" || die "Another SSH rule overrides '$option' for $username."
done
if [[ -n $allow_file ]] && ! grep -Eq "$has_user" <<< "$effective"; then
    die "Another SSH rule overrides the AllowUsers entry for $username."
fi

if [[ -n $key ]]; then
    # Write as the new user so files in their home are owned by that user.
    runuser -u "$username" -- sh -ec '
        cd "$1"
        umask 077
        install -d -m 0700 .ssh
        cat > .ssh/authorized_keys
        chmod 0600 .ssh/authorized_keys
    ' sh "$user_home" <<< "$key"
else
    passwd "$username"
fi

# An idle, socket-activated sshd reads the new files when it starts.
if (( ${#changed_files[@]} )); then
    service_state=$(systemctl show --property=ActiveState --value ssh.service)
    if [[ $service_state == active || $service_state == reloading ]]; then
        reload_attempted=1
        systemctl reload ssh.service
    fi
fi
printf 'Created user %s.\n' "$username"
