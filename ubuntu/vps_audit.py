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


def public_bind(address):
    host = address.rsplit(":", 1)[0].strip("[]").split("%")[0]
    if host == "*":
        return True
    try:
        ip = ipaddress.ip_address(host)
        return not (ip.is_loopback or getattr(ip, "ipv4_mapped", None) and ip.ipv4_mapped.is_loopback)
    except ValueError:
        return True


def report():
    print("Review these non-loopback listeners (actual reachability also depends on firewalls):", flush=True)
    rows = subprocess.check_output(["ss", "-H", "-ltunp"], text=True)
    for row in rows.splitlines():
        if public_bind(row.split()[4]):
            print(" ", row)
    if shutil.which("docker"):
        print("Review Docker-published ports for direct access to apps:", flush=True)
        subprocess.run(["docker", "ps", "--format", "{{.Names}}\t{{.Ports}}"], check=False)
    for user in os.environ.get("AGENT_USERS", "").split():
        if not re.fullmatch(r"[a-z_][a-z0-9_-]*", user):
            raise ValueError("Invalid account in AGENT_USERS")
        groups = subprocess.check_output(["id", "-nG", "--", user], text=True).split()
        if "docker" in groups:
            print(f"WARNING: {user} can control the host through Docker.")
        # A restricted NOPASSWD rule can grant selected commands only.
        listing = subprocess.run(["sudo", "-l", "-U", user], capture_output=True, text=True)
        if "NOPASSWD:" in listing.stdout:
            print(f"WARNING: {user} has a passwordless sudo rule; review sudo -l -U {user}.")
    host = os.environ.get("TUNNEL_HOSTNAME")
    if host:
        validate_hostname(host)
        check_hostname(host)
        print("From a computer outside the VPS network, test every public origin address:\n"
              f"  python ubuntu/vps_audit.py external {host} --origin <IP> --port <app-port>\n"
              "Repeat --origin for IPv4 and IPv6 and --port for each origin port.")


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
        sys.exit(str(exc))
