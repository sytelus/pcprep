#!/bin/bash
#
# security_status.sh - VPS Security Status Check Script
#
# Description:
#   This script performs a quick security audit of your Linux VPS to help
#   determine if the machine may have been compromised. It checks recent
#   logins, SSH authentication logs, user accounts, listening ports,
#   running processes, and fail2ban status.
#
# Usage:
#   sudo ./security_status.sh
#
# Requirements:
#   - Must be run as root or with sudo
#   - Works on Debian/Ubuntu and RHEL/CentOS systems
#
# Output:
#   Displays security-relevant information organized by category.
#   Review the output for any suspicious entries.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root or with sudo${NC}"
   exit 1
fi

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

print_info() {
    echo -e "${GREEN}[*] $1${NC}"
}

# System Information
print_header "SYSTEM INFORMATION"
echo "Hostname: $(hostname)"
echo "Date: $(date)"
echo "Uptime: $(uptime -p)"
echo "Kernel: $(uname -r)"

# Recent Logins
print_header "RECENT LOGINS (last 20)"
print_info "Look for unfamiliar IPs or usernames"
last -20 || echo "Could not retrieve login history"

# Currently Logged In Users
print_header "CURRENTLY LOGGED IN USERS"
who || echo "No users currently logged in"

# Failed Login Attempts
print_header "RECENT FAILED LOGIN ATTEMPTS (last 20)"
print_info "High numbers from single IPs may indicate brute force attacks"
if [[ -f /var/log/auth.log ]]; then
    grep "Failed password" /var/log/auth.log 2>/dev/null | tail -20 || echo "No failed attempts found"
elif [[ -f /var/log/secure ]]; then
    grep "Failed password" /var/log/secure 2>/dev/null | tail -20 || echo "No failed attempts found"
else
    echo "Auth log not found"
fi

# Successful SSH Logins
print_header "SUCCESSFUL SSH LOGINS (last 20)"
print_info "Verify all logins are from recognized IPs"
if [[ -f /var/log/auth.log ]]; then
    grep "Accepted" /var/log/auth.log 2>/dev/null | tail -20 || echo "No successful logins found"
elif [[ -f /var/log/secure ]]; then
    grep "Accepted" /var/log/secure 2>/dev/null | tail -20 || echo "No successful logins found"
else
    echo "Auth log not found"
fi

# User Accounts with Shell Access
print_header "USER ACCOUNTS WITH SHELL ACCESS"
print_info "Verify all accounts are legitimate"
grep -E "bash|sh$" /etc/passwd

# Recently Modified User Accounts
print_header "RECENTLY MODIFIED PASSWD/SHADOW FILES"
echo "Last modified /etc/passwd: $(stat -c %y /etc/passwd)"
echo "Last modified /etc/shadow: $(stat -c %y /etc/shadow)"

# Sudoers
print_header "USERS WITH SUDO PRIVILEGES"
print_info "Check for unauthorized sudo users"
grep -v "^#" /etc/sudoers 2>/dev/null | grep -v "^$" || echo "Could not read sudoers"
if [[ -d /etc/sudoers.d ]]; then
    echo ""
    echo "Files in /etc/sudoers.d/:"
    ls -la /etc/sudoers.d/ 2>/dev/null
fi

# Listening Ports
print_header "LISTENING NETWORK PORTS"
print_info "Look for unexpected services"
ss -tulpn | grep LISTEN

# SSH Configuration
print_header "SSH CONFIGURATION HIGHLIGHTS"
print_info "Verify settings match your expectations"
if [[ -f /etc/ssh/sshd_config ]]; then
    echo "PermitRootLogin: $(grep -E "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "not set (default)")"
    echo "PasswordAuthentication: $(grep -E "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "not set (default)")"
    echo "PubkeyAuthentication: $(grep -E "^PubkeyAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "not set (default)")"
fi

# Authorized Keys
print_header "AUTHORIZED SSH KEYS"
print_info "Verify all keys are recognized"
for user_home in /home/* /root; do
    if [[ -f "$user_home/.ssh/authorized_keys" ]]; then
        user=$(basename "$user_home")
        [[ "$user_home" == "/root" ]] && user="root"
        echo ""
        echo "Keys for $user:"
        cat "$user_home/.ssh/authorized_keys" 2>/dev/null | while read -r key; do
            echo "  - $(echo "$key" | awk '{print $NF}')"
        done
    fi
done

# Fail2ban Status
print_header "FAIL2BAN STATUS"
if command -v fail2ban-client &> /dev/null; then
    fail2ban-client status 2>/dev/null || echo "fail2ban not running"
    echo ""
    echo "SSH jail status:"
    fail2ban-client status sshd 2>/dev/null || echo "sshd jail not found"
else
    print_warning "fail2ban is not installed"
fi

# Cron Jobs
print_header "SYSTEM CRON JOBS"
print_info "Look for suspicious scheduled tasks"
echo "System crontab:"
cat /etc/crontab 2>/dev/null | grep -v "^#" | grep -v "^$"
echo ""
echo "Cron directories:"
for dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly; do
    if [[ -d "$dir" ]]; then
        echo "$dir: $(ls "$dir" 2>/dev/null | tr '\n' ' ')"
    fi
done

# User Cron Jobs
print_header "USER CRON JOBS"
for user in $(cut -f1 -d: /etc/passwd); do
    crontab_content=$(crontab -u "$user" -l 2>/dev/null | grep -v "^#" | grep -v "^$")
    if [[ -n "$crontab_content" ]]; then
        echo "Crontab for $user:"
        echo "$crontab_content"
        echo ""
    fi
done

# Recent Package Installations (Debian/Ubuntu)
print_header "RECENT PACKAGE ACTIVITY (last 10)"
if [[ -f /var/log/dpkg.log ]]; then
    grep " install " /var/log/dpkg.log 2>/dev/null | tail -10 || echo "No recent installations"
elif [[ -f /var/log/yum.log ]]; then
    tail -10 /var/log/yum.log 2>/dev/null || echo "No recent installations"
elif command -v dnf &> /dev/null; then
    dnf history list 2>/dev/null | head -12 || echo "No recent installations"
else
    echo "Package log not found"
fi

# Summary
print_header "SUMMARY"
echo "Review the information above for:"
echo "  1. Unfamiliar IP addresses in login history"
echo "  2. Unknown user accounts with shell access"
echo "  3. Unexpected listening ports or services"
echo "  4. Unrecognized SSH keys in authorized_keys"
echo "  5. Suspicious cron jobs"
echo "  6. Recent package installations you didn't make"
echo ""
echo -e "${GREEN}Security check complete.${NC}"
