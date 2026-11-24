#!/usr/bin/env bash
# Harden an Ubuntu 24.04 or 26.04 LTS VPS and move SSH from TCP 22 to TCP 443.
# Run after ubuntu/min_system.sh. From the repository root, for example:
#   sudo SSH_ALLOWED_USER=shitals bash ubuntu/vps_setup.sh
#
# Before running, test the chosen user's existing SSH key. Reserve TCP 443 for
# SSH (including on a host intended for HTTPS) and allow it in the provider
# firewall. Keep your current session open until a second login on 443 succeeds.
#
# System changes with default settings
#
# - Moves SSH from port 22 to port 443 and starts it automatically at boot.
# - Restricts SSH access to one selected non-root account.
# - Enables SSH key login and disables password and keyboard-interactive login.
# - Disables graphical application forwarding over SSH (X11).
# - Enables the firewall, blocking incoming traffic and allowing outgoing traffic by default.
# - Allows SSH on port 443 and removes the old SSH and Mosh firewall rules.
# - Enables Fail2ban and replaces any custom rules in its main local configuration.
# - Blocks an IP from SSH for one hour after five failed logins in ten minutes.
# - Blocks an IP on all ports for seven days after five bans in one day.
# - Checks for package updates daily and installs eligible updates automatically.
# - Schedules required reboots for 03:30 server time, even with users logged in.
# - Saves a private run log and backups of the SSH, update and Fail2ban files it replaces.
set -Eeuo pipefail
# UFW status is human-readable and translated. Parse its C-locale output.
export LC_ALL=C

RUN_ID="$(date +%Y%m%d_%H%M%S)"
SSH_PORT_OLD=22
SSH_PORT_NEW=443
BACKUP_DIR="/root/vps_setup_backup_${RUN_ID}"
LOG_FILE="/var/log/vps_setup_${RUN_ID}.log"
SSH_ALLOWED_USER="${SSH_ALLOWED_USER:-}"
ALLOWED_USER=""

# The sshd jail counts authentication failures. The recidive jail counts prior
# bans. For each jail, MAXRETRY is the threshold within FINDTIME and BANTIME is
# the ban duration. The numeric time values below are in seconds.
FAIL2BAN_IGNOREIP="${FAIL2BAN_IGNOREIP:-127.0.0.1/8 ::1}"
FAIL2BAN_MAXRETRY="${FAIL2BAN_MAXRETRY:-5}"
FAIL2BAN_FINDTIME="${FAIL2BAN_FINDTIME:-600}"
FAIL2BAN_BANTIME="${FAIL2BAN_BANTIME:-3600}"
FAIL2BAN_RECIDIVE_MAXRETRY="${FAIL2BAN_RECIDIVE_MAXRETRY:-5}"
FAIL2BAN_RECIDIVE_FINDTIME="${FAIL2BAN_RECIDIVE_FINDTIME:-86400}"
FAIL2BAN_RECIDIVE_BANTIME="${FAIL2BAN_RECIDIVE_BANTIME:-604800}"
AUTO_REBOOT_TIME="${AUTO_REBOOT_TIME:-03:30}"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { printf '%s [INFO] %s\n' "$(ts)" "$*"; }
ok() { printf '%s [OK] %s\n' "$(ts)" "$*"; }
fail() { printf '%s [FAIL] %s\n' "$(ts)" "$*" >&2; }

on_error() {
    local code=$?
    local line=$1
    fail "Unhandled error at line $line while running: ${BASH_COMMAND}"
    fail "See log: $LOG_FILE"
    exit "$code"
}

trap 'on_error $LINENO' ERR

init_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    if command -v tee >/dev/null 2>&1; then
        exec > >(tee -a "$LOG_FILE") 2>&1
    else
        exec >>"$LOG_FILE" 2>&1
    fi

    log "Logging started"
    log "Run ID: $RUN_ID"
    log "Log file: $LOG_FILE"
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        fail "Run as root: sudo $0"
        exit 1
    fi
}

require_supported_ubuntu() {
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ ${ID:-} != ubuntu || ! ${VERSION_ID:-} =~ ^(24|26)\.04$ ]]; then
        fail "Expected Ubuntu 24.04 or 26.04 LTS; found ${PRETTY_NAME:-unknown}"
        exit 1
    fi
}

require_commands() {
    local missing=()
    local cmd
    for cmd in sshd ufw fail2ban-client nft unattended-upgrade systemctl ss awk grep id; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if ((${#missing[@]})); then
        fail "Missing commands: ${missing[*]}"
        fail "Install required packages first via ubuntu/min_system.sh"
        exit 1
    fi
    if ! /usr/bin/python3 -c 'from systemd import journal'; then
        fail "Install python3-systemd for the Fail2ban SSH journal backend"
        exit 1
    fi
}

resolve_allowed_user() {
    # Prefer the explicit account, then the caller recorded by sudo, then USER.
    # The chosen account becomes the sole AllowUsers entry written below.
    if [[ -n "$SSH_ALLOWED_USER" && "$SSH_ALLOWED_USER" != "root" ]]; then
        ALLOWED_USER="$SSH_ALLOWED_USER"
    elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        ALLOWED_USER="${SUDO_USER}"
    elif [[ -n "${USER:-}" && "${USER}" != "root" ]]; then
        ALLOWED_USER="${USER}"
    else
        fail "Cannot infer non-root SSH user. Re-run with SSH_ALLOWED_USER=<user>."
        exit 1
    fi

    if ! id "$ALLOWED_USER" >/dev/null 2>&1; then
        fail "User '$ALLOWED_USER' does not exist"
        exit 1
    fi

    ok "SSH restricted user: $ALLOWED_USER"
}

backup_configs() {
    # These copies support manual recovery of the files we edit. UFW rules
    # and systemd unit states are outside the scope of this backup.
    log "Creating configuration backup directory"
    install -d -m 0700 "$BACKUP_DIR"
    cp -p /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config"
    [[ -f /etc/fail2ban/jail.local ]] && cp /etc/fail2ban/jail.local "$BACKUP_DIR/jail.local"
    [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]] && cp /etc/apt/apt.conf.d/20auto-upgrades "$BACKUP_DIR/20auto-upgrades"
    [[ -f /etc/apt/apt.conf.d/52unattended-upgrades-local ]] && cp /etc/apt/apt.conf.d/52unattended-upgrades-local "$BACKUP_DIR/52unattended-upgrades-local"
    ok "Backups saved to $BACKUP_DIR"
}

prepare_ssh_config() {
    # Put global options before cloud-init snippets. OpenSSH uses the first
    # value for most settings. Preserve per-user settings inside Match blocks.
    local candidate="$BACKUP_DIR/sshd_config.candidate"
    {
        printf 'Port %s\nAllowUsers %s\n' "$SSH_PORT_NEW" "$ALLOWED_USER"
        cat <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
X11Forwarding no
EOF
        awk '
            tolower($1) == "match" { in_match = 1 }
            !in_match && tolower($1) ~ /^(port|allowusers|passwordauthentication|kbdinteractiveauthentication|permitrootlogin|pubkeyauthentication|x11forwarding)$/ { next }
            { print }
        ' "$BACKUP_DIR/sshd_config"
    } >"$candidate"

    # Socket activation can leave /run/sshd absent until the first connection.
    install -d -m 0755 /run/sshd
    local effective ports users
    effective=$(sshd -T -f "$candidate")
    # Port and AllowUsers accumulate across includes. Detect conflicts before
    # touching the running daemon. A ListenAddress may specify its own port.
    ports=$(awk '$1 == "port" {print $2} $1 == "listenaddress" {sub(/^.*:/, "", $2); print $2}' <<<"$effective" | sort -u)
    users=$(awk '$1 == "allowusers" {for (i=2; i<=NF; i++) print $i}' <<<"$effective" | sort -u)
    if [[ $ports != "$SSH_PORT_NEW" || $users != "$ALLOWED_USER" ]]; then
        fail "An included SSH configuration adds ports or users. Review sshd -T -f $candidate"
        exit 1
    fi

    # Match User/Address/LocalPort can change authentication for the chosen
    # account. Use the current client's address when sudo passes it through.
    local client_ip client_port server_ip server_port expected
    read -r client_ip client_port server_ip server_port <<<"${SSH_CONNECTION:-127.0.0.1 0 127.0.0.1 22}"
    effective=$(sshd -T -f "$candidate" -C "user=$ALLOWED_USER,addr=$client_ip,host=$client_ip,laddr=$server_ip,lport=$SSH_PORT_NEW")
    for expected in 'pubkeyauthentication yes' 'passwordauthentication no' 'kbdinteractiveauthentication no'; do
        if ! grep -Fxq "$expected" <<<"$effective"; then
            fail "Expected '$expected' for $ALLOWED_USER. Review the SSH Match blocks before retrying."
            exit 1
        fi
    done
}

first_ufw_rule_number_matching() {
    local needle=$1
    ufw status numbered | awk -v needle="$needle" '
        /^\[/ {
            number = $0
            sub(/^\[[[:space:]]*/, "", number)
            sub(/\].*$/, "", number)
            sub(/^\[[^]]*\][[:space:]]*/, "")
            # Only match the destination field. Comments and other ports can
            # also contain the text being searched for.
            if (!found && $1 == needle) { print number; found = 1 }
        }
    '
}

delete_ufw_rules_matching() {
    local needle=$1
    local label=$2
    local deleted=0
    local rule_number

    # UFW renumbers entries after each deletion. Look up the next number from
    # fresh status output so duplicate and IPv6 entries are handled correctly.
    while true; do
        rule_number="$(first_ufw_rule_number_matching "$needle")"
        [[ -z "$rule_number" ]] && break

        log "Deleting UFW rule #$rule_number: $label"
        ufw --force delete "$rule_number" >/dev/null
        deleted=$((deleted + 1))
    done

    if ((deleted > 0)); then
        ok "Removed $deleted UFW rule(s): $label"
    else
        log "No UFW rule matched: $label"
    fi
}

configure_auto_updates() {
    # Replace both APT snippets. The periodic values are intervals in days.
    # If an upgrade requires a reboot, allow it at AUTO_REBOOT_TIME (server
    # local time) even when users are logged in.
    log "Writing unattended-upgrades configuration"
    cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

    cat >/etc/apt/apt.conf.d/52unattended-upgrades-local <<EOF
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
Unattended-Upgrade::Automatic-Reboot-Time "${AUTO_REBOOT_TIME}";
EOF

    log "Enabling unattended-upgrades service and apt timers"
    systemctl enable unattended-upgrades >/dev/null
    systemctl restart unattended-upgrades >/dev/null
    systemctl enable apt-daily.timer apt-daily-upgrade.timer >/dev/null
    systemctl start apt-daily.timer apt-daily-upgrade.timer >/dev/null
    ok "Automatic security updates and reboot policy configured"
}

configure_fail2ban() {
    local ssh_port=$1

    # This replaces jail.local, including any custom jails in that file.
    # sshd reads the system journal. Recidive reads Fail2ban's own
    # ban history and applies its longer ban across all ports.
    log "Writing fail2ban jail.local configuration (sshd port: $ssh_port)"
    cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = $FAIL2BAN_IGNOREIP
bantime = $FAIL2BAN_BANTIME
findtime = $FAIL2BAN_FINDTIME
maxretry = $FAIL2BAN_MAXRETRY

[sshd]
enabled = true
port = $ssh_port
filter = sshd
backend = systemd
journalmatch = _SYSTEMD_UNIT=ssh.service + _COMM=sshd + _COMM=sshd-session + _COMM=sshd-auth

[recidive]
enabled = true
backend = polling
logpath = /var/log/fail2ban.log
banaction = %(banaction_allports)s
findtime = $FAIL2BAN_RECIDIVE_FINDTIME
bantime = $FAIL2BAN_RECIDIVE_BANTIME
maxretry = $FAIL2BAN_RECIDIVE_MAXRETRY
EOF

    # A fresh installation may never have started the daemon. Create its
    # default log if needed so the recidive jail can validate its input.
    if [[ ! -e /var/log/fail2ban.log ]]; then
        install -m 0640 /dev/null /var/log/fail2ban.log
    fi
    fail2ban-client -t
    log "Enabling and restarting fail2ban"
    systemctl enable fail2ban >/dev/null
    systemctl restart fail2ban
    ok "fail2ban configured: sshd + recidive"
}

remove_mosh_rule() {
    delete_ufw_rules_matching "60000:61000/udp" "Mosh range (60000:61000/udp)"
}

ssh_ufw_action() {
    # Retain existing source restrictions on a VPS with an active firewall.
    # UFW puts the optional IPv6 marker between the destination and action.
    awk -v rule="$1/tcp" '$1 == rule {
        i = ($2 == "(v6)" ? 3 : 2)
        if ($(i+1) != "OUT" && !found) { print $i; found = 1 }
    }'
}

allow_ssh_port() {
    local status action
    status=$(ufw status)
    action=$(ssh_ufw_action "$1" <<<"$status")
    case $action in
        ALLOW|LIMIT) log "Keeping existing UFW rule for $1/tcp" ;;
        "") ufw allow "$1/tcp" comment "$2" ;;
        *) fail "UFW has a $action rule for $1/tcp. Review it before switching SSH."; exit 1 ;;
    esac
}

configure_firewall() {
    log "Allowing SSH before enabling UFW or changing the listener"
    local old_listeners
    old_listeners=$(ss -H -ltn "sport = :$SSH_PORT_OLD")
    if [[ -n $old_listeners ]]; then
        allow_ssh_port "$SSH_PORT_OLD" "Temporary SSH bootstrap"
    fi
    allow_ssh_port "$SSH_PORT_NEW" "SSH"
    ufw default deny incoming
    ufw default allow outgoing
    if ! grep -Fxq "Status: active" <<<"$(ufw status)"; then
        ufw --force enable
    fi
}

sshd_owns_new_port() {
    ss -H -ltnp "sport = :$SSH_PORT_NEW" | awk '
        { seen = 1; if (!index($0, "\"sshd\"")) other = 1 }
        END { exit !(seen && !other) }
    '
}

configure_ssh_443_only() {
    local had_socket=false socket_enabled=false service_enabled=false
    if systemctl is-active --quiet ssh.socket; then had_socket=true; fi
    if systemctl is-enabled --quiet ssh.socket; then socket_enabled=true; fi
    if systemctl is-enabled --quiet ssh.service; then service_enabled=true; fi

    # Stop socket activation so systemd does not hand sshd the old listener.
    # Keep the old firewall allowance until sshd owns the destination port.
    install -m 0600 "$BACKUP_DIR/sshd_config.candidate" /etc/ssh/sshd_config
    if switch_ssh_listener "$had_socket" "$socket_enabled" && sshd_owns_new_port &&
        ! systemctl is-active --quiet ssh.socket; then
        ok "sshd is listening on port $SSH_PORT_NEW"
    else
        fail "SSH cutover failed. Restoring the previous configuration and listener"
        cp -p "$BACKUP_DIR/sshd_config" /etc/ssh/sshd_config
        systemctl daemon-reload
        if "$socket_enabled"; then systemctl enable ssh.socket; fi
        if ! "$service_enabled"; then systemctl disable ssh.service; fi
        if "$had_socket"; then
            systemctl stop ssh.service
            systemctl start ssh.socket
        else
            systemctl restart ssh.service
        fi
        exit 1
    fi

    delete_ufw_rules_matching "$SSH_PORT_OLD/tcp" "legacy SSH port $SSH_PORT_OLD"
    delete_ufw_rules_matching "OpenSSH" "legacy OpenSSH profile rule"
    remove_mosh_rule
}

switch_ssh_listener() {
    if [[ $1 == true || $2 == true ]]; then
        systemctl disable --now ssh.socket || return 1
    fi
    systemctl enable ssh.service && systemctl restart ssh.service
}

verify_state() {
    log "Verification"

    local failures=0
    local checks=0
    local ufw_status
    local sshd_effective

    # Each check takes a description followed by a command and its arguments.
    # Count failed checks so the operator sees all mismatches in one run.
    check() {
        local message=$1
        shift
        checks=$((checks + 1))
        if "$@"; then
            ok "$message"
        else
            fail "$message"
            failures=$((failures + 1))
        fi
    }

    # Read configuration as data. An SSH banner or firewall comment may contain
    # quotes and shell metacharacters.
    sshd_effective=$(sshd -T)
    ufw_status=$(ufw status)
    local old_listeners
    old_listeners=$(ss -H -ltn "sport = :$SSH_PORT_OLD")
    check "sshd config is valid" sshd -t
    check "sshd uses port $SSH_PORT_NEW" grep -Fxq "port $SSH_PORT_NEW" <<<"$sshd_effective"
    check "SSH root login disabled" grep -Fxq 'permitrootlogin no' <<<"$sshd_effective"
    check "SSH password login disabled" grep -Fxq 'passwordauthentication no' <<<"$sshd_effective"
    check "SSH keyboard-interactive login disabled" grep -Fxq 'kbdinteractiveauthentication no' <<<"$sshd_effective"
    check "SSH public-key login enabled" grep -Fxq 'pubkeyauthentication yes' <<<"$sshd_effective"
    check "SSH X11 forwarding disabled" grep -Fxq 'x11forwarding no' <<<"$sshd_effective"
    check "SSH allows $ALLOWED_USER" grep -Fxq "allowusers $ALLOWED_USER" <<<"$sshd_effective"
    check "sshd owns TCP port $SSH_PORT_NEW" sshd_owns_new_port
    check "No TCP listener on :$SSH_PORT_OLD" test -z "$old_listeners"
    check "UFW is active" grep -Fxq "Status: active" <<<"$ufw_status"
    check "UFW allows $SSH_PORT_NEW/tcp" grep -Exq 'ALLOW|LIMIT' <<<"$(ssh_ufw_action "$SSH_PORT_NEW" <<<"$ufw_status")"
    check "UFW has no $SSH_PORT_OLD/tcp rule" test -z "$(first_ufw_rule_number_matching "$SSH_PORT_OLD/tcp")"
    check "UFW has no Mosh range rule" test -z "$(first_ufw_rule_number_matching '60000:61000/udp')"
    check "ssh.service is enabled" systemctl is-enabled --quiet ssh.service
    check "ssh.socket is disabled" sh -c '! systemctl is-enabled --quiet ssh.socket'
    check "fail2ban is active" systemctl is-active --quiet fail2ban
    check "fail2ban has sshd jail" fail2ban-client status sshd
    check "fail2ban has recidive jail" fail2ban-client status recidive
    check "fail2ban ignoreip configured" grep -Fxq "ignoreip = $FAIL2BAN_IGNOREIP" /etc/fail2ban/jail.local
    check "Unattended upgrades enabled" systemctl is-enabled --quiet unattended-upgrades
    check "Apt daily upgrade timer enabled" systemctl is-enabled --quiet apt-daily-upgrade.timer
    check "Automatic reboot enabled" grep -Fxq 'Unattended-Upgrade::Automatic-Reboot "true";' /etc/apt/apt.conf.d/52unattended-upgrades-local
    check "Automatic reboot with users enabled" grep -Fxq 'Unattended-Upgrade::Automatic-Reboot-WithUsers "true";' /etc/apt/apt.conf.d/52unattended-upgrades-local

    printf '\nChecked: %d, Failed: %d\n' "$checks" "$failures"
    printf 'Backups: %s\n' "$BACKUP_DIR"
    printf 'Log file: %s\n' "$LOG_FILE"
    printf 'SSH test: ssh -p %s %s@<server>\n' "$SSH_PORT_NEW" "$ALLOWED_USER"

    if ((failures > 0)); then
        exit 1
    fi
    ok "All verification checks passed"
}

main() {
    require_root
    init_logging
    require_supported_ubuntu
    require_commands
    resolve_allowed_user
    log "Starting VPS hardening run"
    backup_configs
    # Reserve TCP 443 for SSH. Permit reruns when sshd already owns it.
    local listeners
    listeners=$(ss -H -ltn "sport = :$SSH_PORT_NEW")
    if [[ -n $listeners ]] && ! sshd_owns_new_port; then
        fail "TCP $SSH_PORT_NEW is in use by another listener. SSH configuration was not changed."
        exit 1
    fi
    prepare_ssh_config
    configure_auto_updates
    configure_fail2ban "$SSH_PORT_NEW"
    configure_firewall
    configure_ssh_443_only
    verify_state
}

main "$@"
