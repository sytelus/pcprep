"""Exercise the automatic-update check without an Ubuntu host or root access."""

import io
import subprocess
import sys
import unittest
from contextlib import ExitStack, redirect_stdout
from types import SimpleNamespace
from unittest.mock import Mock, call, patch

import verify_security_updates as verify


class SecurityUpdatesTest(unittest.TestCase):
    def setUp(self):
        stack = ExitStack()
        self.addCleanup(stack.close)
        stack.enter_context(redirect_stdout(io.StringIO()))
        stack.enter_context(patch.object(verify.platform, "freedesktop_os_release",
                                         return_value={"ID": "ubuntu", "VERSION_CODENAME": "resolute"}))
        stack.enter_context(patch.object(verify.Path, "is_file", return_value=True))
        stack.enter_context(patch.object(verify.os, "geteuid", create=True, return_value=1000))
        self.run_command = stack.enter_context(patch.object(verify.subprocess, "run"))
        self.run_command.return_value.stdout = "LoadState=loaded\nResult=success\n"
        self.apt = Mock()
        self.apt.config.find_b.return_value = True
        self.apt.config.find.return_value = "1"
        self.index = SimpleNamespace(origin="Ubuntu", archive="resolute-security")
        self.apt.Cache.return_value.file_list = [self.index]
        stack.enter_context(patch.dict(sys.modules, apt_pkg=self.apt))
        self.allowed = Mock(return_value=True)
        stack.enter_context(patch.object(verify.runpy, "run_path", return_value={
            "get_allowed_origins": lambda: ["o=Ubuntu,a=resolute-security"],
            "is_allowed_origin": self.allowed,
        }))

    def test_checks_both_timers_then_refreshes_and_simulates(self):
        verify.main()
        expected = []
        for job in ("apt-daily", "apt-daily-upgrade"):
            for action in ("is-enabled", "is-active"):
                expected.append(call(["/usr/bin/systemctl", action, "--quiet", job + ".timer"], check=True))
            expected.append(call(["/usr/bin/systemctl", "show", "--property=LoadState,Result", job + ".service"],
                                 capture_output=True, text=True, check=True))
        expected.append(call(["/usr/bin/sudo", "/usr/bin/apt-get", "--error-on=any", "update"], check=True))
        expected.append(call(["/usr/bin/sudo", "/usr/bin/unattended-upgrade", "--dry-run", "--verbose"], check=True))
        self.assertEqual(self.run_command.call_args_list, expected)
        self.allowed.assert_called_once_with(self.index, ["o=Ubuntu,a=resolute-security"])

    def test_disabled_periodic_updates(self):
        self.apt.config.find_b.return_value = False
        with self.assertRaisesRegex(SystemExit, "APT::Periodic::Enable"):
            verify.main()
        self.apt.config.find_b.return_value = True
        self.apt.config.find.side_effect = ["1", "0"]
        with self.assertRaisesRegex(SystemExit, "Unattended-Upgrade"):
            verify.main()
        self.run_command.assert_not_called()

    def test_requires_an_eligible_security_index_for_this_release(self):
        for archive, eligible in [("resolute", True), ("noble-security", True), ("resolute-security", False)]:
            with self.subTest(archive=archive, eligible=eligible):
                self.index.archive = archive
                self.allowed.return_value = eligible
                with self.assertRaisesRegex(SystemExit, "resolute-security"):
                    verify.main()
                self.assertEqual(self.run_command.call_args.args[0][-1], "update")

    def test_a_failed_timer_index_refresh_or_simulation_fails_the_check(self):
        for position in range(8):
            with self.subTest(position=position):
                self.run_command.side_effect = [self.run_command.return_value] * position + [subprocess.CalledProcessError(1, "check")]
                with self.assertRaises(subprocess.CalledProcessError):
                    verify.main()

    def test_healthy_timers_cannot_hide_masked_or_failed_services(self):
        for state in ("LoadState=masked\nResult=success", "LoadState=loaded\nResult=exit-code"):
            with self.subTest(state=state):
                self.run_command.return_value.stdout = state
                with self.assertRaisesRegex(SystemExit, "apt-daily.service"):
                    verify.main()


if __name__ == "__main__":
    unittest.main()
