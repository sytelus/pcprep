#!/bin/bash
#
# vps_setup.sh - Ubuntu VPS SSH & Security Setup Script
#
# Description:
#   This script configures a new Ubuntu VPS with secure SSH settings,
#   enables SSH on port 443 (to bypass restrictive networks like universities),
#   configures the firewall, and installs fail2ban for brute-force protection.
#
# What this script does:
#   1. Updates the system packages
#   2. Installs fail2ban for brute-force protection
#   3. Configures SSH to listen on both port 22 and 443
#   4. Disables systemd socket activation (so sshd_config is respected)
#   5. Configures UFW firewall to allow SSH on both ports
#   6. Enables services to start on boot
#   7. Verifies all settings and prints status
#
# Usage:
#   sudo ./vps_setup.sh
#
# Requirements:
#   - Ubuntu 20.04, 22.04, or 24.04
#   - Must be run as root or with sudo
#   - Run this from Hetzner console (not SSH) to avoid lockout
#
# Author: Generated for shitals
# Date: 2026-02-06
#

set -e  # Exit on any error

#######################################
# Configuration Variables
# Modify these if needed
#######################################

SSH_PORT_PRIMARY=22      # Standard SSH port (keep for compatibility)
SSH_PORT_SECONDARY=443   # Secondary port (bypasses most firewalls)
BACKUP_DIR="/root/setup_backups_$(date +%Y%m%d_%H%M%S)"

#######################################
# Color Output Functions
#######################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

print_info() {
    echo -e "[*] $1"
}

#######################################
# Pre-flight Checks
#######################################

print_header "PRE-FLIGHT CHECKS"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root or with sudo"
    echo "Usage: sudo $0"
    exit 1
fi
print_success "Running as root"

# Check if Ubuntu
if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    print_warning "This script is designed for Ubuntu. Proceed with caution."
else
    ubuntu_version=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    print_success "Ubuntu $ubuntu_version detected"
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
print_success "Backup directory created: $BACKUP_DIR"

#######################################
# Step 1: Update System Packages
#######################################

print_header "STEP 1: UPDATING SYSTEM PACKAGES"

print_info "Updating package lists..."
apt-get update -qq

print_info "Upgrading installed packages..."
apt-get upgrade -y -qq

print_success "System packages updated"

#######################################
# Step 2: Install Required Packages
#######################################

print_header "STEP 2: INSTALLING REQUIRED PACKAGES"

# Install fail2ban for brute-force protection
if ! command -v fail2ban-client &> /dev/null; then
    print_info "Installing fail2ban..."
    apt-get install -y -qq fail2ban
    print_success "fail2ban installed"
else
    print_success "fail2ban already installed"
fi

# Install ufw if not present
if ! command -v ufw &> /dev/null; then
    print_info "Installing ufw firewall..."
    apt-get install -y -qq ufw
    print_success "ufw installed"
else
    print_success "ufw already installed"
fi

# Install at for scheduled tasks (useful for temporary unbans)
if ! command -v at &> /dev/null; then
    print_info "Installing at scheduler..."
    apt-get install -y -qq at
    print_success "at scheduler installed"
else
    print_success "at scheduler already installed"
fi

#######################################
# Step 3: Configure SSH
#######################################

print_header "STEP 3: CONFIGURING SSH"

SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup original sshd_config
if [[ -f "$SSHD_CONFIG" ]]; then
    cp "$SSHD_CONFIG" "$BACKUP_DIR/sshd_config.backup"
    print_success "Backed up sshd_config to $BACKUP_DIR/"
fi

# Remove any existing Port directives and add our ports
print_info "Configuring SSH ports ($SSH_PORT_PRIMARY and $SSH_PORT_SECONDARY)..."

# Comment out existing Port lines
sed -i 's/^Port /#Port /g' "$SSHD_CONFIG"

# Check if our port configuration already exists
if ! grep -q "^Port $SSH_PORT_PRIMARY$" "$SSHD_CONFIG"; then
    # Add port configuration after the commented Port line or at the beginning
    if grep -q "#Port " "$SSHD_CONFIG"; then
        # Add after the first commented Port line
        sed -i "0,/#Port /{s/#Port .*/#Port 22\nPort $SSH_PORT_PRIMARY\nPort $SSH_PORT_SECONDARY/}" "$SSHD_CONFIG"
    else
        # Add at the beginning of the file
        sed -i "1i Port $SSH_PORT_PRIMARY\nPort $SSH_PORT_SECONDARY" "$SSHD_CONFIG"
    fi
fi

# Ensure key-based authentication is enabled
print_info "Ensuring secure SSH settings..."

# Enable public key authentication
if grep -q "^#*PubkeyAuthentication" "$SSHD_CONFIG"; then
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
else
    echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"
fi

# Disable root login with password (allow only with key)
if grep -q "^#*PermitRootLogin" "$SSHD_CONFIG"; then
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSHD_CONFIG"
else
    echo "PermitRootLogin prohibit-password" >> "$SSHD_CONFIG"
fi

print_success "SSH configuration updated"

# Validate SSH configuration
print_info "Validating SSH configuration..."
if sshd -t 2>/dev/null; then
    print_success "SSH configuration is valid"
else
    print_error "SSH configuration has errors!"
    print_info "Restoring backup..."
    cp "$BACKUP_DIR/sshd_config.backup" "$SSHD_CONFIG"
    print_error "Please check your SSH configuration manually"
    exit 1
fi

#######################################
# Step 4: Disable systemd Socket Activation
#######################################

print_header "STEP 4: DISABLING SYSTEMD SOCKET ACTIVATION"

# Socket activation overrides sshd_config port settings
# We need to disable it so our port configuration is respected

print_info "Checking ssh.socket status..."

if systemctl is-active --quiet ssh.socket 2>/dev/null; then
    print_info "Stopping ssh.socket..."
    systemctl stop ssh.socket
    print_success "ssh.socket stopped"
fi

if systemctl is-enabled --quiet ssh.socket 2>/dev/null; then
    print_info "Disabling ssh.socket..."
    systemctl disable ssh.socket 2>/dev/null
    print_success "ssh.socket disabled (will not start on boot)"
else
    print_success "ssh.socket already disabled"
fi

# Ensure ssh.service is enabled
print_info "Enabling ssh.service..."
systemctl enable ssh 2>/dev/null
print_success "ssh.service enabled (will start on boot)"

# Restart SSH service
print_info "Restarting SSH service..."
systemctl restart ssh
print_success "SSH service restarted"

#######################################
# Step 5: Configure Firewall (UFW)
#######################################

print_header "STEP 5: CONFIGURING FIREWALL"

# Allow SSH on both ports BEFORE enabling firewall
print_info "Allowing SSH on port $SSH_PORT_PRIMARY..."
ufw allow $SSH_PORT_PRIMARY/tcp comment "SSH primary" >/dev/null
print_success "Port $SSH_PORT_PRIMARY allowed"

print_info "Allowing SSH on port $SSH_PORT_SECONDARY..."
ufw allow $SSH_PORT_SECONDARY/tcp comment "SSH secondary (bypass restrictive networks)" >/dev/null
print_success "Port $SSH_PORT_SECONDARY allowed"

# Allow established connections (important for current session)
print_info "Configuring default policies..."
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null

# Enable UFW if not already enabled
if ! ufw status | grep -q "Status: active"; then
    print_info "Enabling UFW firewall..."
    # Use --force to avoid interactive prompt
    ufw --force enable >/dev/null
    print_success "UFW firewall enabled"
else
    print_success "UFW firewall already active"
fi

#######################################
# Step 6: Configure fail2ban
#######################################

print_header "STEP 6: CONFIGURING FAIL2BAN"

FAIL2BAN_LOCAL="/etc/fail2ban/jail.local"

# Create jail.local if it doesn't exist
print_info "Configuring fail2ban..."

cat > "$FAIL2BAN_LOCAL" << 'EOF'
# fail2ban local configuration
# This file overrides settings in jail.conf

[DEFAULT]
# Ban duration: 1 hour (3600 seconds)
bantime = 3600

# Time window to count failures: 10 minutes
findtime = 600

# Number of failures before ban
maxretry = 5

# Whitelist localhost
ignoreip = 127.0.0.1/8 ::1

# Action to take (ban IP using UFW)
banaction = ufw

[sshd]
enabled = true
port = 22,443
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
EOF

print_success "fail2ban configuration created"

# Restart fail2ban
print_info "Restarting fail2ban..."
systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban
print_success "fail2ban restarted"

#######################################
# Step 7: Verification
#######################################

print_header "STEP 7: VERIFICATION"

echo ""
ERRORS=0

# Check SSH is listening on both ports
print_info "Checking SSH listening ports..."
if ss -tlnp | grep -q ":$SSH_PORT_PRIMARY "; then
    print_success "SSH listening on port $SSH_PORT_PRIMARY"
else
    print_error "SSH NOT listening on port $SSH_PORT_PRIMARY"
    ERRORS=$((ERRORS + 1))
fi

if ss -tlnp | grep -q ":$SSH_PORT_SECONDARY "; then
    print_success "SSH listening on port $SSH_PORT_SECONDARY"
else
    print_error "SSH NOT listening on port $SSH_PORT_SECONDARY"
    ERRORS=$((ERRORS + 1))
fi

# Check ssh.socket is disabled
print_info "Checking ssh.socket status..."
if ! systemctl is-enabled --quiet ssh.socket 2>/dev/null; then
    print_success "ssh.socket is disabled"
else
    print_error "ssh.socket is still enabled"
    ERRORS=$((ERRORS + 1))
fi

# Check ssh.service is enabled
print_info "Checking ssh.service status..."
if systemctl is-enabled --quiet ssh 2>/dev/null; then
    print_success "ssh.service is enabled"
else
    print_error "ssh.service is not enabled"
    ERRORS=$((ERRORS + 1))
fi

# Check UFW status
print_info "Checking UFW firewall..."
if ufw status | grep -q "Status: active"; then
    print_success "UFW firewall is active"
else
    print_error "UFW firewall is not active"
    ERRORS=$((ERRORS + 1))
fi

# Check UFW rules
if ufw status | grep -q "$SSH_PORT_PRIMARY/tcp"; then
    print_success "UFW allows port $SSH_PORT_PRIMARY"
else
    print_error "UFW does not allow port $SSH_PORT_PRIMARY"
    ERRORS=$((ERRORS + 1))
fi

if ufw status | grep -q "$SSH_PORT_SECONDARY/tcp"; then
    print_success "UFW allows port $SSH_PORT_SECONDARY"
else
    print_error "UFW does not allow port $SSH_PORT_SECONDARY"
    ERRORS=$((ERRORS + 1))
fi

# Check fail2ban status
print_info "Checking fail2ban status..."
if systemctl is-active --quiet fail2ban; then
    print_success "fail2ban is running"
else
    print_error "fail2ban is not running"
    ERRORS=$((ERRORS + 1))
fi

#######################################
# Summary
#######################################

print_header "SETUP COMPLETE"

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}"
    echo "  All checks passed!"
    echo -e "${NC}"
else
    echo -e "${RED}"
    echo "  $ERRORS check(s) failed. Please review the errors above."
    echo -e "${NC}"
fi

echo "Configuration Summary:"
echo "  - SSH listening on ports: $SSH_PORT_PRIMARY, $SSH_PORT_SECONDARY"
echo "  - UFW firewall: active"
echo "  - fail2ban: active"
echo "  - Backups saved to: $BACKUP_DIR"
echo ""
echo "Connection commands:"
echo "  Standard:    ssh -i <key> user@<ip>"
echo "  Port 443:    ssh -i <key> -p 443 user@<ip>"
echo ""
echo "Next steps:"
echo "  1. Test SSH connection from another terminal BEFORE closing this session"
echo "  2. Test connection on port 443 from restrictive networks (e.g., university)"
echo "  3. Optionally reboot and verify everything starts correctly"
echo ""

# Show current listening ports
print_header "CURRENT SSH LISTENING PORTS"
ss -tlnp | grep sshd

# Show UFW status
print_header "CURRENT UFW RULES"
ufw status numbered

# Show fail2ban status
print_header "FAIL2BAN STATUS"
fail2ban-client status sshd 2>/dev/null || echo "sshd jail not yet active (will be active after first log entry)"

echo ""
print_warning "IMPORTANT: Test your SSH connection before closing this session!"
echo ""
