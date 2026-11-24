#!/usr/bin/python3
"""Stage VPS login changes, then confirm them from a new SSH session."""
import fnmatch
import json
import os
from pathlib import Path
import pwd
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

SSH = Path("/etc/ssh/sshd_config")
DROP = SSH.parent / "sshd_config.d/00-00-pcprep.conf"
USERS = DROP.with_name("00-pcprep-users.conf")
PENDING = Path("/run/pcprep-vps-pending")
UFW = [Path("/etc/default/ufw"), Path("/etc/ufw/ufw.conf"),
       Path("/etc/ufw/user.rules"), Path("/etc/ufw/user6.rules")]
TAG = "pcprep SSH"
JAIL = Path("/etc/fail2ban/jail.d/90-pcprep.local")
CLOUD_SUDOERS = Path("/etc/sudoers.d/90-cloud-init-users")
# A single-user Match block, as add_user.sh writes for each account it creates.
MATCH_USER = re.compile(r"(?im)^[ \t]*Match[ \t]+User[ \t]+([a-z_][a-z0-9_-]*)[ \t]*(?:#.*)?$")
# The first line marks files pcprep owns. Older releases wrote it from
# vps_setup.sh, which vps_harden.sh replaced; keep the text unchanged so reruns
# still recognize and update files written by those releases.
# OpenSSH already chooses modern ciphers and key exchange, and from 10.x (Ubuntu
# 26.04) slows repeat offenders with PerSourcePenalties; fail2ban covers 24.04.
# On top of key-only login, the policy:
# - blocks agent forwarding, so root on this server (or an agent with sudo)
#   can't use the SSH keys on your computer;
# - allows 3 key attempts per connection and 30 seconds to log in;
# - closes sessions whose client stops answering for 15 minutes;
# - logs the fingerprint of the key used for each login (LogLevel VERBOSE),
#   which tells apart accounts that share keys.
POLICY = """# Managed by pcprep vps_setup.sh
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
X11Forwarding no
AllowAgentForwarding no
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 3
LogLevel VERBOSE
"""


def run(*args, capture=False):
    return subprocess.run(args, check=True, text=True,
                          stdout=subprocess.PIPE if capture else None).stdout


def active(unit):
    return subprocess.run(["systemctl", "is-active", "--quiet", unit]).returncode == 0


def read(path):
    return path.read_text() if path.exists() else ""


def write(path, data, mode=0o600):
    # Stage beside the destination for atomic replacement. Never follow a
    # site-specific symlink or overwrite another tool's dedicated snippet.
    if path.is_symlink():
        raise ValueError(f"Refusing to replace symlink {path}")
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as f:
        tmp = Path(f.name)
        try:
            f.write(data.encode())
        except BaseException:
            f.close()
            tmp.unlink(missing_ok=True)
            raise
    try:
        tmp.chmod(mode)
        tmp.replace(path)
    finally:
        tmp.unlink(missing_ok=True)


def values(config, key):
    return [v for line in config.splitlines() if line.startswith(key + " ")
            for v in line.split()[1:]]


def admin_covered(entries, admin):
    # Retain user@host restrictions and glob patterns verbatim in their file.
    # Never turn a restricted grant into an unrestricted one.
    return any(fnmatch.fnmatchcase(admin, entry.partition("@")[0].lstrip("!"))
               for entry in entries)


def match_users(texts):
    """Accounts that have their own single-user Match block in sshd_config."""
    names = []
    for text in texts:
        for name in MATCH_USER.findall(text):
            if name not in names:
                names.append(name)
    return names


def local_user(name):
    try:
        return pwd.getpwnam(name)
    except KeyError:
        return None


def approved_users(admin):
    """The admin, then every existing non-root account with its own Match block.
    Accounts created without add_user.sh need a Match block or AllowUsers entry."""
    files = [SSH, *sorted(SSH.parent.glob("sshd_config.d/*.conf"))]
    users = [admin]
    for name in match_users(read(path) for path in files):
        entry = local_user(name)
        if entry and entry.pw_uid != 0 and name not in users:
            users.append(name)
    return users


def provider_users(keep):
    """The cloud image's default account and other cloud-init sudo accounts."""
    names = {"ubuntu"}
    for line in read(CLOUD_SUDOERS).splitlines():
        match = re.match(r"\s*([a-z_][a-z0-9_-]*)\s+ALL\s*=", line)
        if match:
            names.add(match[1])
    return [name for name in sorted(names - set(keep))
            if (entry := local_user(name)) and entry.pw_uid >= 1000]


def disable_provider_users(names):
    # Disable without deleting: lock the password, expire the account (which
    # also blocks SSH keys through PAM) and remove the login shell.
    for name in names:
        run("usermod", "--lock", "--expiredate", "1", "--shell", "/usr/sbin/nologin", name)
        print(f"Provider account {name} is disabled; its home and files are kept. To undo:\n"
              f"  sudo usermod --unlock --expiredate '' --shell /bin/bash {name}")


def port_number(text):
    if not re.fullmatch(r"[1-9][0-9]{0,4}", text) or int(text) > 65535:
        raise ValueError(f"Invalid TCP port: {text}")
    return text


def ssh_ports(config):
    return set(values(config, "port")) | {addr.rsplit(":", 1)[-1]
                                          for addr in values(config, "listenaddress")}


def migrate_main(text, old):
    # Legacy pcprep versions wrote Port directly to the main file. Only remove
    # a plain global directive for the old port on an explicit migration.
    head, *tail = re.split(r"(?im)(?=^\s*Match[\s=])", text, maxsplit=1)
    head = re.sub(r"(?im)^[ \t]*Port(?:[ \t]+|=)" + old +
                  r"[ \t]*(?:#[^\n]*)?\n", "", head)
    return head + "".join(tail)


def firewall_plan(output, old, new, enabled):
    """Clone simple destination rules, retaining source, address family and action.
    Leave complex site policy to the operator rather than guessing at precedence.
    """
    rules = [shlex.split(line)[1:] for line in output.splitlines() if line.startswith("ufw ")]
    adds, cleanup = [], []
    old_found = new_found = False
    for rule in rules:
        bare = rule[:rule.index("comment")] if "comment" in rule else rule
        if "out" in bare or bare[:1] == ["route"]:
            continue
        old_tokens = {old, old + "/tcp"}
        if old == "22":
            old_tokens.add("OpenSSH")
        if "proto" in bare and bare[bare.index("proto") + 1] == "udp":
            continue
        targets = [i for i, token in enumerate(bare)
                   if token in old_tokens and
                   (i == 1 or bare[i-1] in ("port", "app", "in"))]
        if new != old and any(t in (new, new + "/tcp") for t in bare):
            new_found = True
        if not targets:
            continue
        i = targets[-1]
        if "from" in bare and "port" in bare and (("to" not in bare) or i < bare.index("to")):
            continue
        old_found = True
        if old == new:
            continue
        if bare[0] not in ("limit", "allow", "deny", "reject"):
            raise ValueError("Review the existing SSH firewall policy before migrating.")
        clone = list(bare)
        if bare[i] == "OpenSSH" and i > 1 and bare[i-1] == "app":
            clone[i-1:i+1] = ["port", new, "proto", "tcp"]
        elif i == 1 or bare[i-1] == "in":
            clone[i] = new + "/tcp"
        else:
            clone[i] = new
            if "proto" not in clone:
                clone += ["proto", "tcp"]
        adds.append(clone + ["comment", TAG])
        if rule[len(bare):] == ["comment", TAG]:
            cleanup.append(bare)
    if new != old and new_found:
        raise ValueError("Destination port already has UFW rules. Review them before migrating SSH.")
    if new != old:
        # A broader, compound or profile rule may affect either port. Refuse
        # automatic translation unless every inbound rule has a known destination.
        for rule in rules:
            bare = rule[:rule.index("comment")] if "comment" in rule else rule
            if "out" in bare or bare[:1] == ["route"]:
                continue
            spec = bare[1:]
            if spec[:1] == ["in"]:
                spec = spec[1:]
            if len(spec) == 1 and (spec[0].endswith("/udp") or spec[0] == "OpenSSH" or
                                   re.fullmatch(r"\d+(?:/(?:tcp|udp))?", spec[0])):
                continue
            if ("to" in spec and "port" in spec[spec.index("to"):] and
                spec[spec.index("port", spec.index("to"))+1].isdigit() and
                "port" not in spec[:spec.index("to")]):
                continue
            raise ValueError("Complex inbound UFW rules require a manual SSH port migration.")
    if not old_found and not rules:
        if enabled:
            raise ValueError("Active firewall has no saved SSH rule. Review access before applying.")
        adds.insert(0, ["allow", old + "/tcp", "comment", TAG])
        if old != new:
            adds.append(["allow", new + "/tcp", "comment", TAG])
            cleanup.append(["allow", old + "/tcp"])
    elif not old_found and (not enabled or new != old):
        raise ValueError("Existing UFW policy has no explicit SSH rule. Add a scoped SSH rule first.")
    return adds, cleanup


def reload_ssh(socket, ports_changed):
    run("sshd", "-t")
    if socket and ports_changed:
        run("systemctl", "daemon-reload")
        # Ubuntu's socket generator reads the ports on daemon-reload. Restart
        # both units together so sshd relinquishes any inherited listening FDs.
        run("systemctl", "restart", "ssh.socket", "ssh.service")
    elif active("ssh.service"):
        run("systemctl", "reload", "ssh.service")
    elif not socket:
        raise ValueError("Neither SSH service nor socket is active.")


def ssh_acl(lines, port):
    """Compare UFW's compiled TCP rules within one address family, in order."""
    acl = []
    for line in lines.splitlines():
        if not re.match(r"^-A ufw6?-user-input ", line):
            continue
        rule = shlex.split(line)
        if "-p" not in rule or rule[rule.index("-p") + 1] != "tcp" or "--dport" not in rule:
            continue
        dest = rule.index("--dport") + 1
        if rule[dest] != port:
            continue
        rule[dest] = "SSH"
        # Application-profile labels appear only on the original rule.
        if "--comment" in rule:
            idx = rule.index("--comment")
            if rule[idx-2:idx] == ["-m", "comment"]:
                del rule[idx-2:idx+2]
        acl.append(rule)
    return acl


def check_listeners(ports):
    # A successful service reload can return before sshd finishes rebinding.
    for _ in range(20):
        listeners = run("ss", "-H", "-ltnp", capture=True).splitlines()
        for port in ports:
            rows = [row for row in listeners if row.split()[3].rsplit(":", 1)[-1] == port]
            if not rows or any('"sshd"' not in row and '"systemd"' not in row for row in rows):
                break
        else:
            return
        time.sleep(0.1)
    raise ValueError(f"SSH listener missing or conflicting on {port}")


def validate(ports, user, target, others=()):
    config = run("sshd", "-T", capture=True)
    allowed = values(config, "allowusers")
    if ssh_ports(config) != set(ports) or not all(admin_covered(allowed, u) for u in (user, *others)):
        raise ValueError("SSH includes conflict with the intended ports or approved users.")
    connection = os.environ.get("SSH_CONNECTION", "").split()
    client, local = (connection[0], connection[2]) if len(connection) == 4 else ("127.0.0.1", "127.0.0.1")
    opts = run("sshd", "-T", "-C", f"user={user},host={client},addr={client},laddr={local},lport={target}", capture=True)
    for key, value in (("passwordauthentication", "no"), ("kbdinteractiveauthentication", "no"),
                       ("pubkeyauthentication", "yes"), ("authenticationmethods", "publickey"),
                       ("x11forwarding", "no"), ("permitrootlogin", "no"),
                       ("allowagentforwarding", "no"), ("maxauthtries", "3")):
        if values(opts, key) != [value]:
            raise ValueError(f"SSH configuration overrides {key} for {user}")


def finish(state):
    PENDING.unlink()
    subprocess.run(["systemctl", "stop", state["unit"] + ".timer"], check=False)


def restore(folder, state):
    print("Restoring previous SSH and firewall settings.", flush=True)
    if state["firewall"] and not state["enabled"]:
        run("ufw", "--force", "disable")
    for name, backup in state["backups"].items():
        path = Path(name)
        if backup:
            shutil.copy2(folder / backup, path)
        else:
            path.unlink(missing_ok=True)
    if state["firewall"] and state["enabled"]:
        run("ufw", "reload")
    reload_ssh(state["socket"], state["migrate"])
    if state["migrate"]:
        run("fail2ban-client", "reload", "--restart", "sshd")
    finish(state)


def fresh_ssh_session(ready_ticks):
    # Reject a previously open session, even when sudo stripped SSH_CONNECTION
    # from the process that began setup. sshd-session exists on newer OpenSSH.
    pid = os.getppid()
    while pid > 1:
        proc = Path(f"/proc/{pid}/stat").read_text()
        name, fields = proc.split("(", 1)[1].rsplit(")", 1)
        items = fields.split()
        if name in ("sshd", "sshd-session") and int(items[19]) >= ready_ticks:
            return True
        pid = int(items[1])
    return False


def confirm(folder, state, connection):
    parts = connection.split()
    if (os.environ.get("SUDO_USER") != state["admin"] or len(parts) != 4 or
        parts[3] != state["new"] or connection == state["original"] or
        not fresh_ssh_session(state["ready_ticks"])):
        raise ValueError("Confirm using sudo in a new SSH connection on the target port.")
    if state["migrate"]:
        write(DROP, state["final"])
        validate([state["new"]], state["admin"], state["new"])
        reload_ssh(state["socket"], True)
        check_listeners([state["new"]])
        write(JAIL, state["jail_final"], 0o644)
        run("fail2ban-client", "reload", "--restart", "sshd")
        for rule in state["cleanup"]:
            run("ufw", "--force", "delete", *rule)
    finish(state)
    print("SSH login and sudo confirmed. Changes are permanent.")
    disable_provider_users(state.get("providers", []))


def stage(folder, admin):
    if PENDING.exists():
        raise ValueError("Finish the pending SSH change or wait for its rollback timer.")
    if not active("ssh.socket") and not active("ssh.service"):
        raise ValueError("Start the configured SSH service or socket first.")
    global_config = run("sshd", "-T", capture=True)
    ports = ssh_ports(global_config)
    if len(ports) != 1:
        raise ValueError("Multiple existing SSH ports require an explicit operator migration.")
    old = port_number(ports.pop())
    new = port_number(os.environ.get("SSH_PORT") or old)
    migrate = old != new
    if migrate and run("ss", "-H", "-ltn", f"sport = :{new}", capture=True).strip():
        raise ValueError(f"TCP {new} is already in use.")
    owned = read(DROP)
    if DROP.exists() and not owned.startswith("# Managed by pcprep vps_setup.sh\n"):
        raise ValueError(f"Existing operator configuration at {DROP}")
    final = POLICY
    if migrate or re.search(r"(?m)^Port ", owned):
        final += f"Port {new}\n"
    staged = final + (f"Port {old}\n" if migrate else "")
    changes = {}
    if owned != staged:
        changes[DROP] = staged
    # Without an allowlist every account can log in. Keep the admin and the
    # accounts sshd_config gives their own Match block. An existing allowlist
    # is the operator's, so only the admin is added to it.
    existing = values(global_config, "allowusers")
    keep = approved_users(admin) if not existing else [admin]
    missing = [user for user in keep if not admin_covered(existing, user)]
    if missing:
        changes[USERS] = read(USERS) + f"\nAllowUsers {' '.join(missing)}\n"
        print("SSH allowlist adds: " + " ".join(missing))
    providers = provider_users([*approved_users(admin), os.environ.get("SUDO_USER", "")])
    if migrate:
        main = read(SSH)
        candidate = migrate_main(main, old)
        if main != candidate:
            changes[SSH] = candidate
        current_jail = read(JAIL)
        port_line = f"port = {old}\n"
        if port_line not in current_jail:
            raise ValueError("Cannot identify the managed SSH jail port.")
        changes[JAIL] = current_jail.replace(port_line, f"port = {old},{new}\n", 1)
    status = run("ufw", "status", "verbose", capture=True)
    enabled = "Status: active" in status
    adds, cleanup = firewall_plan(run("ufw", "show", "added", capture=True), old, new, enabled)
    firewall = bool(adds or not enabled or "deny (incoming), allow (outgoing)" not in status)
    if not changes and not firewall:
        validate([new], admin, new)
        check_listeners([new])
        print("SSH access and firewall already configured.")
        disable_provider_users(providers)
        return
    state = dict(old=old, new=new, final=final, migrate=migrate, enabled=enabled,
                 socket=active("ssh.socket"), admin=admin, firewall=firewall, cleanup=cleanup,
                 original=os.environ.get("SSH_CONNECTION", ""), backups={}, providers=providers,
                 unit="pcprep-vps-" + folder.name.replace("_", "-"))
    if migrate:
        state["jail_final"] = current_jail.replace(port_line, f"port = {new}\n", 1)
    for index, path in enumerate([*changes, *(UFW if firewall else [])]):
        backup = f"original-{index}" if path.exists() else None
        if backup:
            shutil.copy2(path, folder / backup)
        state["backups"][str(path)] = backup
    helper = folder / "vps_access.py"
    shutil.copyfile(__file__, helper)
    write(folder / "access.json", json.dumps(state))
    run("systemd-run", "--unit=" + state["unit"], "--on-active=10min",
        "--timer-property=AccuracySec=1s", "/usr/bin/python3", str(helper), "rollback", str(folder))
    write(PENDING, str(folder))
    try:
        for path, data in changes.items():
            write(path, data, 0o644 if path == JAIL else 0o600)
        validate([old, new], admin, new, missing)
        if migrate:
            run("fail2ban-client", "reload", "--restart", "sshd")
        if firewall:
            for rule in adds:
                run("ufw", *rule)
            run("ufw", "default", "deny", "incoming")
            run("ufw", "default", "allow", "outgoing")
            if not enabled:
                run("ufw", "--force", "enable")
            applied = run("ufw", "status", "verbose", capture=True)
            if "Status: active" not in applied or "deny (incoming), allow (outgoing)" not in applied:
                raise ValueError("UFW did not activate the requested default policies.")
            if migrate:
                for path in (Path("/etc/ufw/user.rules"), Path("/etc/ufw/user6.rules")):
                    rules = read(path)
                    if ssh_acl(rules, old) != ssh_acl(rules, new):
                        raise ValueError(f"SSH source restrictions differ in {path}; restoring access.")
        reload_ssh(state["socket"], migrate)
        check_listeners({old, new})
        state["ready_ticks"] = int(time.clock_gettime(time.CLOCK_BOOTTIME) * os.sysconf("SC_CLK_TCK"))
        write(folder / "access.json", json.dumps(state))
    except BaseException:
        restore(folder, state)
        raise
    print(f"\nWithin 10 minutes open a NEW connection from your computer:\n"
          f"  ssh -S none -o PreferredAuthentications=publickey -p {new} {admin}@<server>\n"
          f"Then run in that session:\n  sudo /usr/bin/python3 {helper} confirm {folder} "
          '"$SSH_CONNECTION"\nOtherwise previous access is restored automatically.')


def main():
    import fcntl
    if os.geteuid() != 0:
        sys.exit("Run via sudo.")
    os.environ["LC_ALL"] = "C"
    action, directory, *extra = sys.argv[1:]
    folder = Path(directory)
    with open("/run/pcprep-add-user.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if action == "stage":
            stage(folder, extra[0])
        elif read(PENDING) == str(folder):
            state = json.loads((folder / "access.json").read_text())
            if action == "rollback":
                restore(folder, state)
            elif action == "confirm":
                confirm(folder, state, extra[0])
            else:
                raise ValueError("Unknown operation")
        elif action != "rollback":
            sys.exit("This change is no longer pending.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        sys.exit(str(exc))
