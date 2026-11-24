#!/usr/bin/env bash
# Harden an Ubuntu 24.04 or 26.04 VPS serving websites via Cloudflare Tunnel.
# Run after prepare_new_vps.sh, from your admin account: sudo bash ubuntu/vps_harden.sh
# (from another account, name the admin: sudo env SSH_ALLOWED_USER=<admin> bash ...).
# The admin must already log in with an SSH key; the script checks this first.
#
# - Allows key login for the admin. Without an existing SSH allowlist, it also keeps
#   every account that has its own "Match User" block in sshd_config (add_user.sh
#   writes one per account); an existing allowlist is kept as it is.
# - After the new login is confirmed, disables (never deletes) the provider's default
#   account, such as ubuntu, and other cloud-init sudo accounts.
# - Disables root, password and keyboard-interactive SSH login, X11 and agent forwarding;
#   allows 3 key attempts and 30 s to log in, drops dead sessions after 15 min,
#   and logs which key each login used.
# - Keeps the current SSH port and startup mode; set SSH_PORT to request a port move.
# - Restores previous SSH and firewall settings unless a new login confirms access in ten minutes.
# - Enables an incoming-deny, outgoing-allow firewall, keeping SSH source restrictions.
# - Opens no website ports and leaves operator-created firewall rules in place.
# - Bans repeated SSH failures for one hour by default; week-long all-port bans are opt-in.
# - Enables and tests daily security updates, plus updates from the cloudflared, Caddy
#   and GitHub CLI repositories when configured. Reboots when required at 03:30.
# - Reports network listeners, published containers, agent privileges and pending reboots.
# - Saves private logs and copies of settings changed by this script.
#
# Optional: AUTO_REBOOT=0, AUTO_REBOOT_TIME=03:30 (server time), RECIDIVE=1,
# AGENT_USERS="sy_agent sy_dev",
# TUNNEL_HOSTNAME=www.example.com. See docs/UBUNTU.md for the external origin check.
set -Eeuo pipefail
export LC_ALL=C
umask 077
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $EUID == 0 ]] || die "Run with sudo."
. /etc/os-release
[[ $ID == ubuntu && ($VERSION_ID == 24.04 || $VERSION_ID == 26.04) ]] || die "Expected Ubuntu 24.04 or 26.04."
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
admin=${SSH_ALLOWED_USER:-${SUDO_USER:-}}
[[ $admin =~ ^[a-z_][a-z0-9_-]*$ ]] && [[ $(id -u -- "$admin") != 0 ]] && id -- "$admin" >/dev/null ||
    die "Set SSH_ALLOWED_USER to an existing non-root admin."
for cmd in sshd ufw nft fail2ban-client unattended-upgrade systemd-run ss sudo flock; do
    command -v "$cmd" >/dev/null || die "Missing $cmd; install the VPS prerequisites."
done
/usr/bin/python3 -c 'from systemd import journal' || die "Install python3-systemd."

# Hardening turns off SSH passwords, so the admin needs a key on this server
# first. Check the files sshd actually reads (AuthorizedKeysFile).
[[ -d /run/sshd ]] || install -d -m 0755 /run/sshd
admin_home=$(getent passwd -- "$admin" | cut -d: -f6)
admin_has_key=0
for key_file in $(sshd -T -C "user=$admin,host=localhost,addr=127.0.0.1" |
                  awk '$1 == "authorizedkeysfile" { $1 = ""; print }'); do
    [[ $key_file == none ]] && continue
    key_file=${key_file//\%h/$admin_home}
    key_file=${key_file//\%u/$admin}
    [[ $key_file == /* ]] || key_file="$admin_home/$key_file"
    if [[ -f $key_file ]] && grep -Eq '(^|[[:space:]])(ssh-|ecdsa-|sk-)[^[:space:]]+[[:space:]]+AAAA' "$key_file"; then
        admin_has_key=1
    fi
done
(( admin_has_key )) || die "$admin has no SSH key on this server, and hardening turns off SSH passwords.
Add your public key first, from your own computer:
  Windows PowerShell: type \$env:USERPROFILE\\.ssh\\id_ed25519.pub | ssh $admin@<server> \"umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys\"
  Linux, macOS or Git Bash: ssh-copy-id $admin@<server>
(No key yet? Run ssh-keygen -t ed25519 first.) Then log in with the key and run this script again."

auto_reboot=${AUTO_REBOOT:-1}
recidive=${RECIDIVE:-0}
[[ $auto_reboot =~ ^[01]$ && $recidive =~ ^[01]$ ]] || die "AUTO_REBOOT and RECIDIVE accept 0 or 1."
reboot_time=${AUTO_REBOOT_TIME:-03:30}
[[ $reboot_time =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]] || die "Use HH:MM for AUTO_REBOOT_TIME."
# Serialize the setup phase; the confirmation and rollback helper also locks shared SSH edits.
exec 8>/run/pcprep-vps-setup.lock
flock -n 8 || die "Another VPS setup is running."
[[ ! -e /run/pcprep-vps-pending ]] || die "Confirm the pending SSH change or wait for rollback."
backup=$(mktemp -d "/root/vps_setup_backup_$(date +%Y%m%d_%H%M%S)_XXXXXX")
log="/var/log/${backup##*/}.log"
# Output goes through tee, so tell the audit report whether the terminal shows color.
if [[ -t 1 && -z ${NO_COLOR:-} ]]; then export PCPREP_COLOR=1; fi
exec > >(tee -a "$log" 8>&-) 2>&1
printf 'Backups: %s\nLog: %s\n' "$backup" "$log"
[[ -d /run/sshd ]] || install -d -m 0755 /run/sshd
sshd -t
effective=$(sshd -T)
port=$(awk '$1 == "port" {print $2}' <<<"$effective" | sort -u)
[[ $port =~ ^[0-9]+$ ]] || die "Multiple existing SSH ports require a manual migration."

# Replace only pcprep's own snippets. Save a copy for rollback and avoid
# disturbing other files maintained by the operator. Ownership is the first
# line, "Managed by pcprep vps_setup.sh". vps_setup.sh was this script's old
# name; the marker stays unchanged so files from older releases still match.
put_config() {
    local src=$1 dest=$2
    if [[ -e $dest ]]; then
        [[ $(head -n 1 "$dest") == "$(head -n 1 "$src")" ]] ||
            die "Refusing to replace an operator-owned file at $dest"
        cp -p -- "$dest" "$backup/${dest##*/}.before"
    fi
    install -m 0644 "$src" "$dest.new"
    mv -fT "$dest.new" "$dest"
}
undo_config() {
    local dest=$1 previous="$backup/${1##*/}.before"
    if [[ -f $previous ]]; then cp -p -- "$previous" "$dest"; else rm -f -- "$dest"; fi
}

# A later APT snippet also supersedes earlier pcprep versions that enabled
# reboots in 52unattended-upgrades-local, without editing that file. Ubuntu
# updates only its own archives automatically; the patterns add the internet-
# facing tools' own repositories and match nothing when they are not configured.
apt_file=/etc/apt/apt.conf.d/92pcprep-updates
cat >"$backup/updates" <<EOF
// Managed by pcprep vps_setup.sh
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
Unattended-Upgrade::Automatic-Reboot "$([[ $auto_reboot == 1 ]] && echo true || echo false)";
Unattended-Upgrade::Automatic-Reboot-Time "$reboot_time";
Unattended-Upgrade::Origins-Pattern {
    "site=pkg.cloudflare.com,origin=cloudflared";
    "site=dl.cloudsmith.io,origin=cloudsmith/caddy/stable";
    "site=cli.github.com,origin=gh";
};
EOF
put_config "$backup/updates" "$apt_file"
systemctl enable --now unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer
if ! /usr/bin/python3 "$script_dir/verify_security_updates.py"; then
    undo_config "$apt_file"
    die "Security-update verification failed; the previous APT settings were restored."
fi
if [[ -f /run/reboot-required ]]; then printf 'A system reboot is pending.\n'; fi

# Scope the SSH thresholds to this jail, so unrelated applications retain
# their own limits. The explicit recidive choice supersedes old jail.local settings.
jail=/etc/fail2ban/jail.d/90-pcprep.local
cat >"$backup/jails" <<EOF
# Managed by pcprep vps_setup.sh
[sshd]
enabled = true
backend = systemd
journalmatch = _SYSTEMD_UNIT=ssh.service + _COMM=sshd + _COMM=sshd-session + _COMM=sshd-auth
port = $port
ignoreip = ${FAIL2BAN_IGNOREIP:-127.0.0.1/8 ::1}
maxretry = ${FAIL2BAN_MAXRETRY:-5}
findtime = ${FAIL2BAN_FINDTIME:-600}
bantime = ${FAIL2BAN_BANTIME:-3600}

[recidive]
enabled = $([[ $recidive == 1 ]] && echo true || echo false)
EOF
if [[ $recidive == 1 ]]; then
    cat >>"$backup/jails" <<EOF
backend = polling
logpath = /var/log/fail2ban.log
banaction = %(banaction_allports)s
ignoreip = ${FAIL2BAN_IGNOREIP:-127.0.0.1/8 ::1}
maxretry = ${FAIL2BAN_RECIDIVE_MAXRETRY:-5}
findtime = ${FAIL2BAN_RECIDIVE_FINDTIME:-86400}
bantime = ${FAIL2BAN_RECIDIVE_BANTIME:-604800}
EOF
    [[ -e /var/log/fail2ban.log ]] || install -m 0640 /dev/null /var/log/fail2ban.log
fi
put_config "$backup/jails" "$jail"
start_jails() {
    fail2ban-client -t && systemctl enable --now fail2ban || return 1
    # systemd can return before Fail2ban creates its control socket.
    for _ in {1..20}; do
        if fail2ban-client ping >/dev/null 2>&1; then
            fail2ban-client reload
            return
        fi
        sleep 0.25
    done
    return 1
}
if ! start_jails; then
    undo_config "$jail"
    systemctl restart fail2ban
    die "Fail2ban configuration failed; previous settings restored."
fi
fail2ban-client status sshd
if [[ $recidive == 1 ]]; then fail2ban-client status recidive; fi

/usr/bin/python3 "$script_dir/vps_audit.py" report
/usr/bin/python3 "$script_dir/vps_access.py" stage "$backup" "$admin"
