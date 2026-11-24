#!/usr/bin/python3
"""Check Ubuntu's systemd/APT automatic updates and simulate an upgrade."""

import os
import platform
import re
import runpy
import subprocess
import sys
from pathlib import Path


def main():
    release = platform.freedesktop_os_release()
    if release.get("ID") != "ubuntu":
        sys.exit("This check requires Ubuntu.")
    updater = "/usr/bin/unattended-upgrade"
    if not Path(updater).is_file():
        sys.exit("Missing unattended-upgrades. Install the Ubuntu package and retry.")

    try:
        import apt_pkg  # Provided by python3-apt for Ubuntu's system Python.
    except ImportError:
        sys.exit("Install python3-apt and run this check with /usr/bin/python3.")
    apt_pkg.init()
    if not apt_pkg.config.find_b("APT::Periodic::Enable", True):
        sys.exit("APT::Periodic::Enable disables automatic updates.")
    for setting in ("Update-Package-Lists", "Unattended-Upgrade"):
        interval = apt_pkg.config.find(f"APT::Periodic::{setting}", "0")
        if interval != "always" and not re.fullmatch(r"0*[1-9][0-9]*[smhd]?", interval):
            sys.exit(f"APT::Periodic::{setting} has a disabled or invalid interval: {interval!r}")
        print(f"APT::Periodic::{setting} = {interval}")

    # systemctl's multi-unit queries succeed if *any* listed unit passes.
    for job in ("apt-daily", "apt-daily-upgrade"):
        timer = job + ".timer"
        for action in ("is-enabled", "is-active"):
            subprocess.run(["/usr/bin/systemctl", action, "--quiet", timer], check=True)
        service = job + ".service"
        state = subprocess.run(
            ["/usr/bin/systemctl", "show", "--property=LoadState,Result", service],
            capture_output=True, text=True, check=True,
        ).stdout.splitlines()
        if "LoadState=loaded" not in state or "Result=success" not in state:
            sys.exit(f"{service} is unavailable or recorded a failure: {', '.join(state)}")
        print(f"{timer} is enabled and active. {service} is loaded with no recorded failure.", flush=True)

    # An old cache or an empty allowed-origins list can produce a successful
    # dry run with zero updates. Refresh indexes, then use the installed
    # updater's own matching rules, including custom Origins-Pattern entries.
    sudo = [] if os.geteuid() == 0 else ["/usr/bin/sudo"]
    subprocess.run([*sudo, "/usr/bin/apt-get", "--error-on=any", "update"], check=True)
    policy = runpy.run_path(updater)
    allowed = policy["get_allowed_origins"]()
    security_archive = release["VERSION_CODENAME"] + "-security"
    cache = apt_pkg.Cache(None)
    if not any(
        index.origin == "Ubuntu"
        and index.archive == security_archive
        and policy["is_allowed_origin"](index, allowed)
        for index in cache.file_list
    ):
        sys.exit(f"APT has no eligible Ubuntu {security_archive} index for unattended upgrades.")

    subprocess.run([*sudo, updater, "--dry-run", "--verbose"], check=True)
    print(f"Ubuntu automatic security updates verified for {security_archive} (dry run).")


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"Security update verification failed: {error}")
