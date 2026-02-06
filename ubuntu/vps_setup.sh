#!/usr/bin/env bash
set -euo pipefail

SSH_PORT_OLD=22
SSH_PORT_NEW=443
BACKUP_DIR="/root/vps_setup_backup_$(date +%Y%m%d_%H%M%S)"
FAIL2BAN_IGNOREIP="${FAIL2BAN_IGNOREIP:-127.0.0.1/8 ::1 205.175.0.0/16 128.95.0.0/16 140.142.0.0/16}"

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
    for cmd in sshd ufw fail2ban-client systemctl ss awk grep sed; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if ((${#missing[@]})); then
        fail "Missing commands: ${missing[*]}"
        fail "Install required packages first via ubuntu/min_system.sh"
        exit 1
    fi
}

backup_configs() {
    mkdir -p "$BACKUP_DIR"
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config"
    [[ -f /etc/fail2ban/jail.local ]] && cp /etc/fail2ban/jail.local "$BACKUP_DIR/jail.local"
    ok "Backups saved to $BACKUP_DIR"
}

set_sshd_option() {
    local key=$1
    local value=$2
    local file=/etc/ssh/sshd_config

    if grep -Eq "^[#[:space:]]*${key}[[:space:]]+" "$file"; then
        sed -ri "s|^[#[:space:]]*${key}[[:space:]].*|${key} ${value}|g" "$file"
    else
        printf '%s %s\n' "$key" "$value" >>"$file"
    fi
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

configure_fail2ban() {
    local ssh_port=$1

    cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = $FAIL2BAN_IGNOREIP

[sshd]
enabled = true
port = $ssh_port
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF

    systemctl enable fail2ban >/dev/null
    systemctl restart fail2ban
    ok "fail2ban configured for sshd on port $ssh_port"
}

configure_base_security() {
    log "PART 1/2: Secure default Ubuntu 24.04 baseline"

    set_sshd_option PasswordAuthentication no
    set_sshd_option KbdInteractiveAuthentication no
    set_sshd_option PermitRootLogin no
    set_sshd_option PubkeyAuthentication yes
    sshd -t

    systemctl disable --now ssh.socket >/dev/null 2>&1 || true
    systemctl enable ssh >/dev/null
    systemctl restart ssh

    ufw default deny incoming >/dev/null
    ufw default allow outgoing >/dev/null
    ufw allow "${SSH_PORT_OLD}/tcp" comment "Temporary SSH bootstrap" >/dev/null
    ufw --force enable >/dev/null

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

    configure_fail2ban "$SSH_PORT_NEW"
    ok "SSH now restricted to port $SSH_PORT_NEW"
}

verify_state() {
    log "Verification"

    local failures=0
    local checks=0
    local ssh_ports=()
    local ufw_status

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
    ufw_status="$(ufw status)"

    check "sshd config is valid" sshd -t
    check "sshd includes port $SSH_PORT_NEW" contains_ssh_port "$SSH_PORT_NEW"
    if contains_ssh_port "$SSH_PORT_OLD"; then
        fail "sshd still includes port $SSH_PORT_OLD"
        failures=$((failures + 1))
        checks=$((checks + 1))
    else
        ok "sshd no longer includes port $SSH_PORT_OLD"
        checks=$((checks + 1))
    fi

    check "TCP listener exists on :$SSH_PORT_NEW" sh -c "ss -tln | awk '{print \$4}' | grep -Eq '(^|:)${SSH_PORT_NEW}\$'"
    check "No TCP listener on :$SSH_PORT_OLD" sh -c "! ss -tln | awk '{print \$4}' | grep -Eq '(^|:)${SSH_PORT_OLD}\$'"
    check "UFW is active" sh -c "printf '%s\n' \"$ufw_status\" | grep -q 'Status: active'"
    check "UFW allows $SSH_PORT_NEW/tcp" sh -c "printf '%s\n' \"$ufw_status\" | grep -Eq '\\b${SSH_PORT_NEW}/tcp\\b'"
    check "UFW blocks $SSH_PORT_OLD/tcp" sh -c "! printf '%s\n' \"$ufw_status\" | grep -Eq '\\b${SSH_PORT_OLD}/tcp\\b'"
    check "ssh.service is enabled" systemctl is-enabled --quiet ssh
    check "ssh.socket is disabled" sh -c "! systemctl is-enabled --quiet ssh.socket"
    check "fail2ban is active" systemctl is-active --quiet fail2ban
    check "fail2ban has sshd jail" sh -c "fail2ban-client status 2>/dev/null | grep -q 'sshd'"

    printf '\nChecked: %d, Failed: %d\n' "$checks" "$failures"
    printf 'Backups: %s\n' "$BACKUP_DIR"
    printf 'SSH test: ssh -p %s <user>@<server>\n' "$SSH_PORT_NEW"

    if ((failures > 0)); then
        exit 1
    fi
    ok "All verification checks passed"
}

main() {
    require_root
    require_ubuntu_2404
    require_commands
    backup_configs
    configure_base_security
    configure_ssh_443_only
    verify_state
}

main "$@"
