#!/usr/bin/env python3
"""Offline tests for the Bash `ask` and `act` shortcuts in .bash_aliases.

A fake `codex` records each call, so no model is contacted and nothing changes.
Each test starts one shell and runs several requests in it, which keeps the
suite fast.
"""
from __future__ import annotations
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent
SECTIONS = ('USAGE', 'EXAMPLES', 'OPTIONS', 'PERMISSIONS', 'INPUT AND QUOTING',
            'RAW INPUT', 'SETUP', 'OUTPUT AND STATUS')


class ShortcutTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='codex-shortcut-tests-')
        self.base = Path(self.temp.name)
        self.home = self.base / 'my home'
        self.bin = self.home / '.local' / 'bin'
        self.bin.mkdir(parents=True)
        self.capture = self.base / 'capture.jsonl'
        mock = self.bin / 'codex'
        mock.write_text('''#!/usr/bin/env python3
import json, os, sys
record = {"args": sys.argv[1:], "stdin": sys.stdin.read(), "cwd": os.getcwd(),
          "openai_key": os.getenv("OPENAI_API_KEY"), "codex_key": os.getenv("CODEX_API_KEY")}
with open(os.environ["MOCK_CAPTURE"], "a") as f:
    f.write(json.dumps(record) + "\\n")
sys.exit(int(os.getenv("MOCK_EXIT", "0")))
''')
        mock.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        HOME=str(self.home), MOCK_CAPTURE=str(self.capture),
                        OPENAI_API_KEY='test-api-marker', CODEX_API_KEY='test-codex-marker')

    def tearDown(self):
        self.temp.cleanup()

    def run_script(self, script, stdin='', exit_code=0):
        """Run `script` after sourcing the aliases; return the process and Codex calls."""
        self.env['MOCK_EXIT'] = str(exit_code)
        script = 'source ' + shlex.quote(str(ROOT / '.bash_aliases')) + '\n' + script
        p = subprocess.run(['bash', '--noprofile', '--norc', '-c', script], input=stdin, text=True,
                           cwd=self.base, env=self.env, capture_output=True, timeout=30)
        calls = ([json.loads(line) for line in self.capture.read_text().splitlines()]
                 if self.capture.exists() else [])
        return p, calls

    @staticmethod
    def words(call):
        return shlex.split(call['stdin'].split('\nRequest:\n', 1)[1])

    @staticmethod
    def sandbox(call):
        return call['args'][call['args'].index('--sandbox') + 1]

    def test_request_words_reach_codex_unchanged(self):
        (self.base / 'one.tmp').touch()
        p, calls = self.run_script('''
ask show the top 3 processes by CPU usage
act empty "~/my fav/big folder"
act move "first folder" into "second folder"
ask "what is in this folder?"
ask find '*.tmp' in this folder
ask list "./~/my fav"
ask 'explain $(touch SHOULD_NOT_EXIST); echo danger'
ask -- --host is an option
ask explain --help and -h
ask -- --help -h
''')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual([self.words(c) for c in calls], [
            ['show', 'the', 'top', '3', 'processes', 'by', 'CPU', 'usage'],
            ['empty', str(self.home / 'my fav/big folder')],
            ['move', 'first folder', 'into', 'second folder'],
            ['what is in this folder?'],
            ['find', '*.tmp', 'in', 'this', 'folder'],
            ['list', './~/my fav'],
            ['explain $(touch SHOULD_NOT_EXIST); echo danger'],
            ['--host', 'is', 'an', 'option'],
            ['explain', '--help', 'and', '-h'],
            ['--help', '-h'],
        ])
        self.assertFalse((self.base / 'SHOULD_NOT_EXIST').exists())
        self.assertEqual([self.sandbox(c) for c in calls[:2]], ['read-only', 'danger-full-access'])
        self.assertEqual(self.sandbox(calls[7]), 'read-only')

    def test_sandbox_choice_and_exact_codex_arguments(self):
        p, calls = self.run_script('act empty ./temp\nask --host show processes')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(calls[0]['args'], [
            'exec', '--cd', str(self.base), '--skip-git-repo-check', '--ephemeral',
            '--sandbox', 'danger-full-access', '-c', 'approval_policy=never',
            '-c', 'model_provider=openai', '-c', 'forced_login_method=chatgpt',
            '-c', 'hide_agent_reasoning=true', '-c', 'features.apps=false', '-'])
        self.assertEqual(calls[0]['cwd'], str(self.base))
        self.assertIn('ambiguous, print one focused question and STOP', calls[0]['stdin'])
        self.assertIn('no per-command approvals', p.stderr)
        self.assertEqual(self.sandbox(calls[1]), 'danger-full-access')
        self.assertIn('NOT enforced', p.stderr)

    def test_raw_stdin_is_passed_unchanged_and_not_evaluated(self):
        raw = '''empty "~/my fav/big folder"; don't run $(touch BAD) & keep café\n'''
        p, calls = self.run_script('act', stdin=raw)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('Input format: Raw English text.', calls[0]['stdin'])
        self.assertEqual(calls[0]['stdin'].split('\nRequest:\n', 1)[1], raw)
        self.assertFalse((self.base / 'BAD').exists())

    def test_credentials_hidden_from_codex_only_and_status_kept(self):
        p, calls = self.run_script('ask show disk space; echo "STATUS=$?"\n'
                                   'printf "PARENT=%s/%s\\n" "$OPENAI_API_KEY" "$CODEX_API_KEY"',
                                   exit_code=17)
        self.assertIsNone(calls[0]['openai_key'])
        self.assertIsNone(calls[0]['codex_key'])
        self.assertIn('STATUS=17', p.stdout)
        self.assertIn('PARENT=test-api-marker/test-codex-marker', p.stdout)

    def test_only_the_native_codex_executable_is_used(self):
        p, calls = self.run_script('codex() { return 99; }; ask show disk space')
        self.assertEqual((p.returncode, len(calls)), (0, 1), p.stderr)
        self.capture.unlink()
        (self.bin / 'codex').unlink()
        p, calls = self.run_script('ask show disk space; echo "ASK=$?"; act show disk space; echo "ACT=$?"')
        self.assertIn('ASK=127', p.stdout)
        self.assertIn('ACT=127', p.stdout)
        self.assertEqual(p.stderr.count('Native Codex executable not found:'), 2)
        self.assertEqual(calls, [])

    def test_blank_or_missing_input_never_calls_codex(self):
        p, calls = self.run_script('act; echo "BLANK=$?"; ask; echo "EOF=$?"', stdin='   \n')
        self.assertIn('BLANK=2', p.stdout)
        self.assertIn('EOF=2', p.stdout)
        self.assertEqual(calls, [])

    def test_help_is_complete_and_has_no_side_effects(self):
        p, calls = self.run_script('''set -u
ask --help > ask.txt
act -h > act.txt
ask --host -h > host.txt
act --help empty ./temp > extra.txt
(PATH=/nonexistent; act --help > nopath.txt)
IFS= read -r line; printf 'UNREAD=%s\\n' "$line"
printf 'PARENT=%s/%s\\n' "$OPENAI_API_KEY" "$CODEX_API_KEY"
ask show disk space 2>/dev/null
''', stdin='preserved input\n')
        self.assertEqual((p.returncode, p.stderr), (0, ''))
        for mode in ('ask', 'act'):
            text = (self.base / f'{mode}.txt').read_text()
            self.assertTrue(text.startswith(mode + ' - '))
            self.assertIn(f'  {mode} [--host] [--] [request ...]', text)
            for phrase in (*SECTIONS, 'ChatGPT', 'codex login', 'no Codex', '~/my fav/big folder'):
                self.assertIn(phrase, text)
            self.assertIn('read-only' if mode == 'ask' else 'NO per-command', text)
        for name in ('host', 'extra', 'nopath'):
            self.assertIn('USAGE', (self.base / f'{name}.txt').read_text())
        self.assertIn('UNREAD=preserved input', p.stdout)
        self.assertIn('PARENT=test-api-marker/test-codex-marker', p.stdout)
        # Help never calls Codex, and the shortcut still works afterwards.
        self.assertEqual([self.words(c) for c in calls], [['show', 'disk', 'space']])
        self.assertEqual(self.sandbox(calls[0]), 'read-only')


if __name__ == '__main__':
    unittest.main(verbosity=2)
