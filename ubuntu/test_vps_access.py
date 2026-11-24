"""VPS access regressions. These tests never change the host firewall or SSH service."""
import os
from pathlib import Path
import tempfile
import unittest
from contextlib import ExitStack
from unittest.mock import patch

import vps_access as access
import vps_audit as audit


class AccessTests(unittest.TestCase):
    def test_migration_retains_sources_actions_and_operator_rules(self):
        text = """ufw limit from 192.0.2.0/24 to any port 22 proto tcp
ufw allow from 2001:db8::/64 to any port 22 proto tcp
ufw allow 60000:61000/udp"""
        rules, remove = access.firewall_plan(text, "22", "2222", True)
        self.assertEqual(rules, [
            ["limit", "from", "192.0.2.0/24", "to", "any", "port", "2222", "proto", "tcp", "comment", access.TAG],
            ["allow", "from", "2001:db8::/64", "to", "any", "port", "2222", "proto", "tcp", "comment", access.TAG],
        ])
        self.assertEqual(remove, [])

    def test_fresh_install_cleanup_and_rerun(self):
        rules, remove = access.firewall_plan("", "22", "2222", False)
        self.assertEqual([r[1] for r in rules], ["22/tcp", "2222/tcp"])
        self.assertEqual(remove, [["allow", "22/tcp"]])
        saved = "ufw allow 2222/tcp comment 'pcprep SSH'"
        self.assertEqual(access.firewall_plan(saved, "2222", "2222", True), ([], []))
        self.assertEqual(access.firewall_plan(saved, "2222", "22", True)[1], [["allow", "2222/tcp"]])

    def test_conflicting_or_ambiguous_policy_is_rejected_before_migration(self):
        for extra in ["ufw deny 2222/tcp", "ufw allow from 192.0.2.0/24", "ufw allow 22,2222/tcp"]:
            with self.subTest(extra=extra), self.assertRaises(ValueError):
                access.firewall_plan("ufw allow OpenSSH\n" + extra, "22", "2222", True)

    def test_restricted_user_and_match_block_are_preserved(self):
        self.assertTrue(access.admin_covered(["dev", "shitals@192.0.2.*"], "shitals"))
        self.assertFalse(access.admin_covered(["dev", "ubuntu"], "shitals"))
        conf = "Port 443\nAllowUsers shitals dev\nMatch User dev\n    PasswordAuthentication yes\n"
        self.assertEqual(access.migrate_main(conf, "443"), conf.split("\n", 1)[1])

    def test_compiled_acl_detects_a_family_specific_widening(self):
        rules = "-A ufw6-user-input -p tcp --dport 22 -s 2001:db8::/64 -j ACCEPT\n"
        cloned = rules.replace("--dport 22 ", "--dport 2222 ")
        self.assertEqual(access.ssh_acl(rules + cloned, "22"), access.ssh_acl(rules + cloned, "2222"))
        widened = cloned.replace(" -s 2001:db8::/64", "")
        self.assertNotEqual(access.ssh_acl(rules, "22"), access.ssh_acl(widened, "2222"))

    def test_identical_rerun_skips_confirmation_and_mutations(self):
        with tempfile.TemporaryDirectory() as tmp, ExitStack() as m:
            folder = Path(tmp)
            drop = folder / "policy.conf"
            drop.write_text(access.POLICY)
            m.enter_context(patch.object(access, "DROP", drop))
            m.enter_context(patch.object(access, "PENDING", folder / "pending"))
            m.enter_context(patch.object(access, "active", return_value=True))
            m.enter_context(patch.dict(os.environ, SSH_PORT=""))
            responses = {("sshd", "-T"): "port 22\nallowusers dev shitals",
                         ("ufw", "status", "verbose"): "Status: active\nDefault: deny (incoming), allow (outgoing)",
                         ("ufw", "show", "added"): "ufw allow OpenSSH"}
            m.enter_context(patch.object(access, "run", side_effect=lambda *a, **kw: responses[a]))
            m.enter_context(patch.object(access, "validate"))
            m.enter_context(patch.object(access, "check_listeners"))
            access.stage(folder, "shitals")
            self.assertEqual(list(folder.iterdir()), [drop])

    def test_network_report_separates_loopback_from_other_bindings(self):
        for address in ["[::1]:3000", "127.0.0.2:80", "[::ffff:127.0.0.1]:8000"]:
            self.assertFalse(audit.public_bind(address))
        for address in ["[::]:443", "*:8080", "0.0.0.0:80", "192.0.2.10:3000"]:
            self.assertTrue(audit.public_bind(address))

    def test_expiry_restores_files_and_previous_listener_mode(self):
        with tempfile.TemporaryDirectory() as tmp, ExitStack() as mocks:
            folder = Path(tmp)
            managed = folder / "managed.conf"
            managed.write_text("new")
            created = folder / "new.conf"
            created.write_text("new")
            (folder / "original").write_text("old")
            pending = folder / "pending"
            pending.write_text(str(folder))
            mocks.enter_context(patch.object(access, "PENDING", pending))
            command = mocks.enter_context(patch.object(access, "run"))
            reload_ssh = mocks.enter_context(patch.object(access, "reload_ssh"))
            mocks.enter_context(patch.object(access.subprocess, "run"))
            state = dict(backups={str(managed): "original", str(created): None},
                         firewall=True, enabled=True, socket=True, migrate=True, unit="test")
            access.restore(folder, state)
            self.assertEqual(managed.read_text(), "old")
            self.assertFalse(created.exists())
            self.assertFalse(pending.exists())
            reload_ssh.assert_called_once_with(True, True)
            command.assert_any_call("ufw", "reload")

    def test_original_connection_cannot_disarm_timer(self):
        connection = "192.0.2.1 43210 192.0.2.2 22"
        state = dict(admin="shitals", new="22", original=connection)
        with patch.dict(os.environ, SUDO_USER="shitals"), self.assertRaisesRegex(ValueError, "new SSH"):
            access.confirm(None, state, connection)

    def test_fresh_confirm_removes_only_owned_old_rule_after_listener_check(self):
        with tempfile.TemporaryDirectory() as tmp, ExitStack() as m:
            folder = Path(tmp)
            for attr in ("DROP", "JAIL", "PENDING"):
                m.enter_context(patch.object(access, attr, folder / attr))
            access.PENDING.write_text(str(folder))
            m.enter_context(patch.dict(os.environ, SUDO_USER="shitals"))
            m.enter_context(patch.object(access, "fresh_ssh_session", return_value=True))
            m.enter_context(patch.object(access, "validate"))
            m.enter_context(patch.object(access, "reload_ssh"))
            listeners = m.enter_context(patch.object(access, "check_listeners"))
            command = m.enter_context(patch.object(access, "run"))
            m.enter_context(patch.object(access.subprocess, "run"))
            state = dict(admin="shitals", new="2222", original="", ready_ticks=1,
                         migrate=True, final=access.POLICY + "Port 2222\n", socket=True,
                         jail_final="port = 2222\n", cleanup=[["allow", "22/tcp"]], unit="test")
            access.confirm(folder, state, "192.0.2.1 45000 192.0.2.2 2222")
            self.assertFalse(access.PENDING.exists())
            self.assertEqual(access.DROP.read_text(), state["final"])
            self.assertEqual(access.JAIL.read_text(), state["jail_final"])
            listeners.assert_called_once_with(["2222"])
            command.assert_any_call("ufw", "--force", "delete", "allow", "22/tcp")


if __name__ == "__main__":
    unittest.main()
