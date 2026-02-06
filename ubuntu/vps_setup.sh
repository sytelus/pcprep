#!/usr/bin/env bash
set -euo pipefail

SSH_PORT_OLD=22
SSH_PORT_NEW=443
BACKUP_DIR="/root/vps_setup_backup_$(date +%Y%m%d_%H%M%S)"
SSH_ALLOWED_USER="${SSH_ALLOWED_USER:-}"
ALLOWED_USER=""

FAIL2BAN_IGNOREIP="${FAIL2BAN_IGNOREIP:-127.0.0.1/8 ::1}"
FAIL2BAN_MAXRETRY="${FAIL2BAN_MAXRETRY:-5}"
FAIL2BAN_FINDTIME="${FAIL2BAN_FINDTIME:-600}"
FAIL2BAN_BANTIME="${FAIL2BAN_BANTIME:-3600}"
FAIL2BAN_RECIDIVE_MAXRETRY="${FAIL2BAN_RECIDIVE_MAXRETRY:-5}"
FAIL2BAN_RECIDIVE_FINDTIME="${FAIL2BAN_RECIDIVE_FINDTIME:-86400}"
FAIL2BAN_RECIDIVE_BANTIME="${FAIL2BAN_RECIDIVE_BANTIME:-604800}"
AUTO_REBOOT_TIME="${AUTO_REBOOT_TIME:-03:30}"

log() { printf '[*] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        fail "Run as root: sudo $0"
        exit 1
    fi
}

require_ubuntu_2404() {
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ ${ID:-} != "ubuntu" || ${VERSION_ID:-} != "24.04" ]]; then
        fail "Expected Ubuntu 24.04; found ${PRETTY_NAME:-unknown}"
        exit 1
    fi
}

require_commands() {
    local missing=()
    local cmd
    for cmd in sshd ufw fail2ban-client systemctl ss awk grep sed id; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if ((${#missing[@]})); then
        fail "Missing commands: ${missing[*]}"
        fail "Install required packages first via ubuntu/min_system.sh"
        exit 1
    fi
}

resolve_allowed_user() {
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
    mkdir -p "$BACKUP_DIR"
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config"
    [[ -f /etc/fail2ban/jail.local ]] && cp /etc/fail2ban/jail.local "$BACKUP_DIR/jail.local"
    [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]] && cp /etc/apt/apt.conf.d/20auto-upgrades "$BACKUP_DIR/20auto-upgrades"
    [[ -f /etc/apt/apt.conf.d/52unattended-upgrades-local ]] && cp /etc/apt/apt.conf.d/52unattended-upgrades-local "$BACKUP_DIR/52unattended-upgrades-local"
    ok "Backups saved to $BACKUP_DIR"
}

set_sshd_option() {
    local key=$1
    local value=$2
    local file=/etc/ssh/sshd_config

    sed -ri "/^[[:space:]]*${key}[[:space:]]+/d" "$file"
    printf '%s %s\n' "$key" "$value" >>"$file"
}

set_ssh_port_only() {
    local port=$1
    local file=/etc/ssh/sshd_config

    sed -ri '/^[[:space:]]*Port[[:space:]]+[0-9]+/d' "$file"
    if grep -q '^Include /etc/ssh/sshd_config.d/\*\.conf' "$file"; then
        sed -i '/^Include \/etc\/ssh\/sshd_config.d\/\*\.conf/a Port '"$port" "$file"
    else
        sed -i "1i Port $port" "$file"
    fi
}

configure_auto_updates() {
    cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

    cat >/etc/apt/apt.conf.d/52unattended-upgrades-local <<EOF
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
Unattended-Upgrade::Automatic-Reboot-Time "${AUTO_REBOOT_TIME}";
EOF

    systemctl enable unattended-upgrades >/dev/null
    systemctl restart unattended-upgrades >/dev/null || true
    systemctl enable apt-daily.timer apt-daily-upgrade.timer >/dev/null
    systemctl start apt-daily.timer apt-daily-upgrade.timer >/dev/null
    ok "Automatic security updates and reboot policy configured"
}

configure_fail2ban() {
    local ssh_port=$1

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
logpath = /var/log/auth.log

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
banaction = %(banaction_allports)s
findtime = $FAIL2BAN_RECIDIVE_FINDTIME
bantime = $FAIL2BAN_RECIDIVE_BANTIME
maxretry = $FAIL2BAN_RECIDIVE_MAXRETRY
EOF

    systemctl enable fail2ban >/dev/null
    systemctl restart fail2ban
    ok "fail2ban configured: sshd + recidive"
}

remove_mosh_rule() {
    while ufw status | grep -Eq '\b60000:61000/udp\b'; do
        ufw --force delete allow 60000:61000/udp >/dev/null || break
    done
}

configure_base_security() {
    log "PART 1/2: Secure default Ubuntu 24.04 baseline"

    set_sshd_option PasswordAuthentication no
    set_sshd_option KbdInteractiveAuthentication no
    set_sshd_option PermitRootLogin no
    set_sshd_option PubkeyAuthentication yes
    set_sshd_option X11Forwarding no
    set_sshd_option AllowUsers "$ALLOWED_USER"
    sshd -t

    systemctl disable --now ssh.socket >/dev/null 2>&1 || true
    systemctl enable ssh >/dev/null
    systemctl restart ssh

    ufw default deny incoming >/dev/null
    ufw default allow outgoing >/dev/null
    remove_mosh_rule
    ufw allow "${SSH_PORT_OLD}/tcp" comment "Temporary SSH bootstrap" >/dev/null
    ufw --force enable >/dev/null

    configure_auto_updates
    configure_fail2ban "$SSH_PORT_OLD"
    ok "Base hardening complete"
}

configure_ssh_443_only() {
    log "PART 2/2: Move SSH to 443 and disable 22"

    set_ssh_port_only "$SSH_PORT_NEW"
    sshd -t
    systemctl restart ssh

    ufw allow "${SSH_PORT_NEW}/tcp" comment "SSH" >/dev/null

    while ufw status | grep -Eq "\\b${SSH_PORT_OLD}/tcp\\b"; do
        ufw --force delete allow "${SSH_PORT_OLD}/tcp" >/dev/null || break
    done
    while ufw status | grep -q "OpenSSH"; do
        ufw --force delete allow OpenSSH >/dev/null || break
    done
    remove_mosh_rule

    configure_fail2ban "$SSH_PORT_NEW"
    ok "SSH now restricted to port $SSH_PORT_NEW"
}

verify_state() {
    log "Verification"

    local failures=0
    local checks=0
    local ssh_ports=()
    local ufw_status
    local sshd_effective

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

    contains_ssh_port() {
        local wanted=$1
        local p
        for p in "${ssh_ports[@]}"; do
            [[ $p == "$wanted" ]] && return 0
        done
        return 1
    }

    mapfile -t ssh_ports < <(sshd -T 2>/dev/null | awk '$1 == "port" { print $2 }')
    sshd_effective="$(sshd -T 2>/dev/null)"
    ufw_status="$(ufw status)"

    check "sshd config is valid" sshd -t
    check "sshd includes port $SSH_PORT_NEW" contains_ssh_port "$SSH_PORT_NEW"
    check "sshd excludes port $SSH_PORT_OLD" sh -c "! printf '%s\n' \"$sshd_effective\" | grep -Eq '^port ${SSH_PORT_OLD}\$'"
    check "SSH root login disabled" sh -c "printf '%s\n' \"$sshd_effective\" | grep -Eq '^permitrootlogin no\$'"
    check "SSH password login disabled" sh -c "printf '%s\n' \"$sshd_effective\" | grep -Eq '^passwordauthentication no\$'"
    check "SSH X11 forwarding disabled" sh -c "printf '%s\n' \"$sshd_effective\" | grep -Eq '^x11forwarding no\$'"
    check "SSH restricted to user $ALLOWED_USER" sh -c "printf '%s\n' \"$sshd_effective\" | grep -Eq '^allowusers ${ALLOWED_USER}\$'"
    check "TCP listener exists on :$SSH_PORT_NEW" sh -c "ss -tln | awk '{print \$4}' | grep -Eq '(^|:)${SSH_PORT_NEW}\$'"
    check "No TCP listener on :$SSH_PORT_OLD" sh -c "! ss -tln | awk '{print \$4}' | grep -Eq '(^|:)${SSH_PORT_OLD}\$'"
    check "UFW is active" sh -c "printf '%s\n' \"$ufw_status\" | grep -q 'Status: active'"
    check "UFW allows $SSH_PORT_NEW/tcp" sh -c "printf '%s\n' \"$ufw_status\" | grep -Eq '\\b${SSH_PORT_NEW}/tcp\\b'"
    check "UFW blocks $SSH_PORT_OLD/tcp" sh -c "! printf '%s\n' \"$ufw_status\" | grep -Eq '\\b${SSH_PORT_OLD}/tcp\\b'"
    check "UFW has no Mosh range rule" sh -c "! printf '%s\n' \"$ufw_status\" | grep -Eq '\\b60000:61000/udp\\b'"
    check "ssh.service is enabled" systemctl is-enabled --quiet ssh
    check "ssh.socket is disabled" sh -c "! systemctl is-enabled --quiet ssh.socket"
    check "fail2ban is active" systemctl is-active --quiet fail2ban
    check "fail2ban has sshd jail" sh -c "fail2ban-client status 2>/dev/null | grep -q 'sshd'"
    check "fail2ban has recidive jail" sh -c "fail2ban-client status 2>/dev/null | grep -q 'recidive'"
    check "fail2ban ignoreip is localhost only" sh -c "grep -Eq '^ignoreip = 127\\.0\\.0\\.1/8 ::1\$' /etc/fail2ban/jail.local"
    check "Unattended upgrades enabled" systemctl is-enabled --quiet unattended-upgrades
    check "Apt daily upgrade timer enabled" systemctl is-enabled --quiet apt-daily-upgrade.timer
    check "Automatic reboot enabled" sh -c "grep -Eq '^Unattended-Upgrade::Automatic-Reboot \"true\";' /etc/apt/apt.conf.d/52unattended-upgrades-local"
    check "Automatic reboot with users enabled" sh -c "grep -Eq '^Unattended-Upgrade::Automatic-Reboot-WithUsers \"true\";' /etc/apt/apt.conf.d/52unattended-upgrades-local"

    printf '\nChecked: %d, Failed: %d\n' "$checks" "$failures"
    printf 'Backups: %s\n' "$BACKUP_DIR"
    printf 'SSH test: ssh -p %s %s@<server>\n' "$SSH_PORT_NEW" "$ALLOWED_USER"

    if ((failures > 0)); then
        exit 1
    fi
    ok "All verification checks passed"
}

main() {
    require_root
    require_ubuntu_2404
    require_commands
    resolve_allowed_user
    backup_configs
    configure_base_security
    configure_ssh_443_only
    verify_state
}

main "$@"
