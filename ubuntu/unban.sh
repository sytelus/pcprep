#!/bin/bash
#
# unban.sh - Unban IP addresses from fail2ban
#
# Description:
#   This script unbans IP addresses from fail2ban jails. It can unban
#   from a specific jail (like sshd) or from all jails at once.
#
# Usage:
#   sudo ./unban.sh <IP_ADDRESS> [JAIL_NAME]
#
# Arguments:
#   IP_ADDRESS  - The IP address to unban (required)
#   JAIL_NAME   - The jail to unban from (optional, defaults to 'sshd')
#                 Use 'all' to unban from all jails
#
# Examples:
#   sudo ./unban.sh 192.168.1.100           # Unban from sshd jail
#   sudo ./unban.sh 192.168.1.100 sshd      # Unban from sshd jail
#   sudo ./unban.sh 192.168.1.100 all       # Unban from all jails
#
# Requirements:
#   - Must be run as root or with sudo
#   - fail2ban must be installed
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

# Check if fail2ban is installed
if ! command -v fail2ban-client &> /dev/null; then
    echo -e "${RED}Error: fail2ban is not installed${NC}"
    exit 1
fi

# Check arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <IP_ADDRESS> [JAIL_NAME]"
    echo ""
    echo "Arguments:"
    echo "  IP_ADDRESS  - The IP address to unban (required)"
    echo "  JAIL_NAME   - The jail to unban from (optional, defaults to 'sshd')"
    echo "                Use 'all' to unban from all jails"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.100           # Unban from sshd jail"
    echo "  $0 192.168.1.100 sshd      # Unban from sshd jail"
    echo "  $0 192.168.1.100 all       # Unban from all jails"
    echo ""
    echo "Current banned IPs in sshd jail:"
    fail2ban-client status sshd 2>/dev/null | grep "Banned IP" || echo "  No banned IPs or sshd jail not found"
    exit 1
fi

IP_ADDRESS="$1"
JAIL_NAME="${2:-sshd}"

# Validate IP address format (basic check)
if ! [[ $IP_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid IP address format: $IP_ADDRESS${NC}"
    exit 1
fi

# Function to unban from a single jail
unban_from_jail() {
    local jail=$1
    local ip=$2

    echo -n "Unbanning $ip from $jail... "

    # Check if jail exists
    if ! fail2ban-client status "$jail" &>/dev/null; then
        echo -e "${YELLOW}jail not found${NC}"
        return 1
    fi

    # Check if IP is banned in this jail
    banned_ips=$(fail2ban-client status "$jail" 2>/dev/null | grep "Banned IP" | sed 's/.*Banned IP list:\s*//')

    if echo "$banned_ips" | grep -qw "$ip"; then
        if fail2ban-client set "$jail" unbanip "$ip" &>/dev/null; then
            echo -e "${GREEN}success${NC}"
            return 0
        else
            echo -e "${RED}failed${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}IP not banned in this jail${NC}"
        return 0
    fi
}

# Main logic
echo -e "${BLUE}fail2ban Unban Script${NC}"
echo "====================="
echo ""

if [[ "$JAIL_NAME" == "all" ]]; then
    echo "Unbanning $IP_ADDRESS from all jails..."
    echo ""

    # Get list of all jails
    jails=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list:\s*//' | tr ',' '\n' | tr -d '[:space:]')

    if [[ -z "$jails" ]]; then
        echo -e "${RED}No jails found${NC}"
        exit 1
    fi

    for jail in $jails; do
        unban_from_jail "$jail" "$IP_ADDRESS"
    done
else
    echo "Unbanning $IP_ADDRESS from $JAIL_NAME jail..."
    echo ""
    unban_from_jail "$JAIL_NAME" "$IP_ADDRESS"
fi

echo ""
echo -e "${GREEN}Done.${NC}"
echo ""

# Show current status
echo "Current banned IPs in sshd jail:"
fail2ban-client status sshd 2>/dev/null | grep "Banned IP" || echo "  No banned IPs or sshd jail not found"
