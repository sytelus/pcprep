#!/usr/bin/env python3
"""Report VPS exposure locally or check the operator's own origin from a workstation."""
import argparse
import ipaddress
import os
import re
import shutil
import socket
import subprocess
import sys
import urllib.error
import urllib.request

# DHCP clients listen on these UDP ports to get the server's address.
DHCP_CLIENT_PORTS = {"68", "546"}


def use_color(stream=sys.stdout):
    # vps_harden.sh sets PCPREP_COLOR because its output passes through tee.
    if os.environ.get("NO_COLOR"):
        return False
    return os.environ.get("PCPREP_COLOR") == "1" or stream.isatty()


def critical(message, stream=sys.stdout):
    text = f"CRITICAL: {message}"
    print(f"\033[1;31m{text}\033[0m" if use_color(stream) else text, file=stream, flush=True)


def warning(message):
    text = f"WARNING: {message}"
    print(f"\033[1;33m{text}\033[0m" if use_color() else text, flush=True)


def public_bind(address):
    host = address.rsplit(":", 1)[0].strip("[]").split("%")[0]
    if host == "*":
        return True
    try:
        ip = ipaddress.ip_address(host)
        return not (ip.is_loopback or getattr(ip, "ipv4_mapped", None) and ip.ipv4_mapped.is_loopback)
    except ValueError:
        return True


def ssh_ports():
    try:
        config = subprocess.run(["sshd", "-T"], capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return set()
    return {line.split()[1] for line in config.splitlines() if line.startswith("port ")}


def classify(row, ssh):
    """Return "ssh", "dhcp", "critical" or "warning" for one public `ss -ltunp` row."""
    fields = row.split()
    netid, port = fields[0], fields[4].rsplit(":", 1)[-1]
    process = " ".join(fields[6:])
    if netid == "tcp" and port in ssh and ('"sshd"' in process or '"systemd"' in process):
        return "ssh"
    if netid == "udp" and port in DHCP_CLIENT_PORTS:
        return "dhcp"
    return "critical" if netid == "tcp" else "warning"


def published_ports(ports):
    """Docker port mappings that listen on a non-loopback address."""
    return [mapping.strip() for mapping in ports.split(",")
            if "->" in mapping and public_bind(mapping.split("->")[0].strip())]


def report():
    problems = 0
    ssh = ssh_ports()
    print("Listeners on non-loopback addresses (reachability also depends on firewalls):", flush=True)
    rows = subprocess.check_output(["ss", "-H", "-ltunp"], text=True)
    for row in rows.splitlines():
        if not public_bind(row.split()[4]):
            continue
        kind = classify(row, ssh)
        if kind in ("ssh", "dhcp"):
            print(" ", row, flush=True)
        elif kind == "critical":
            problems += 1
            critical(f"public TCP listener; bind it to 127.0.0.1 and publish it through the tunnel:\n  {row}")
        else:
            warning(f"public UDP listener; check that it is expected:\n  {row}")
    if shutil.which("docker"):
        warning("Docker is installed. Its published ports bypass UFW.")
        listing = subprocess.run(["docker", "ps", "--format", "{{.Names}}\t{{.Ports}}"],
                                 capture_output=True, text=True, check=False).stdout
        for line in listing.splitlines():
            name, _, ports = line.partition("\t")
            exposed = published_ports(ports)
            if exposed:
                problems += 1
                critical(f"container {name} publishes {', '.join(exposed)} past the firewall; "
                         "publish on 127.0.0.1 instead.")
    for user in os.environ.get("AGENT_USERS", "").split():
        if not re.fullmatch(r"[a-z_][a-z0-9_-]*", user):
            raise ValueError("Invalid account in AGENT_USERS")
        groups = subprocess.check_output(["id", "-nG", "--", user], text=True).split()
        if "docker" in groups:
            warning(f"{user} can control the host through Docker.")
        # A restricted NOPASSWD rule can grant selected commands only.
        listing = subprocess.run(["sudo", "-l", "-U", user], capture_output=True, text=True)
        if "NOPASSWD:" in listing.stdout:
            print(f"Note: {user} has a passwordless sudo rule; review sudo -l -U {user}.")
    host = os.environ.get("TUNNEL_HOSTNAME")
    if host:
        validate_hostname(host)
        check_hostname(host)
        print("From a computer outside the VPS network, test every public origin address:\n"
              f"  python ubuntu/vps_audit.py external {host} --origin <IP> --port <app-port>\n"
              "Repeat --origin for IPv4 and IPv6 and --port for each origin port.")
    if problems:
        critical(f"{problems} critical exposure issue(s) above need attention.")
    else:
        print("No critical exposure issues found.")


def validate_hostname(host):
    if not re.fullmatch(r"(?=.{1,253}$)(?:[a-zA-Z0-9-]+\.)+[a-zA-Z0-9-]+", host):
        raise ValueError("Supply a DNS hostname without a scheme, path or port.")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None


def check_hostname(host):
    validate_hostname(host)
    opener = urllib.request.build_opener(NoRedirect)
    try:
        response = opener.open("https://" + host + "/", timeout=8)
    except urllib.error.HTTPError as exc:
        response = exc
    with response:
        if not response.headers.get("cf-ray") or not (200 <= response.status < 400):
            raise ValueError(f"{host}: expected HTTPS via Cloudflare, received HTTP {response.status}.")
        print(f"{host}: HTTPS via Cloudflare returned HTTP {response.status}.")


def external(host, origins, ports):
    check_hostname(host)
    exposed = []
    for origin in origins:
        address = str(ipaddress.ip_address(origin))
        for port in ports:
            if not 1 <= port <= 65535:
                raise ValueError("Origin ports must be between 1 and 65535.")
            try:
                with socket.create_connection((address, port), timeout=4):
                    exposed.append(f"[{address}]:{port}")
            except (ConnectionRefusedError, TimeoutError):
                print(f"[{address}]:{port} refused or timed out from this computer.")
    if exposed:
        raise ValueError("Direct TCP access succeeded: " + ", ".join(exposed))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("report")
    cli = sub.add_parser("external")
    cli.add_argument("hostname")
    cli.add_argument("--origin", action="append", required=True)
    cli.add_argument("--port", action="append", required=True, type=int)
    args = parser.parse_args()
    try:
        if args.action == "report":
            report()
        else:
            external(args.hostname, args.origin, args.port)
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        critical(str(exc), sys.stderr)
        sys.exit(1)
