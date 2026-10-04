#!/usr/bin/env python3
"""Offline Bash/Zsh wrapper tests. Uses a fake Codex; no model calls or mutations."""
from __future__ import annotations
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent

class ShortcutTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='codex-shortcut-tests-')
        self.base = Path(self.temp.name)
        self.home = self.base / 'my home'
        self.bin = self.home / '.local' / 'bin'
        self.bin.mkdir(parents=True)
        self.capture = self.base / 'capture.json'
        mock = self.bin / 'codex'
        mock.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
record = {"args":sys.argv[1:],"stdin":sys.stdin.read(),"cwd":os.getcwd(),
          "openai_key":os.getenv("OPENAI_API_KEY"),"codex_key":os.getenv("CODEX_API_KEY")}
Path(os.environ["MOCK_CAPTURE"]).write_text(json.dumps(record))
print("MOCK COMMAND AND OUTPUT")
sys.exit(int(os.getenv("MOCK_EXIT", "0")))
''')
        mock.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin)+os.pathsep+os.environ['PATH'],
                        HOME=str(self.home), MOCK_CAPTURE=str(self.capture),
                        OPENAI_API_KEY='test-api-marker', CODEX_API_KEY='test-codex-marker')
        self.shell = os.environ.get('TEST_SHELL', shutil.which('bash') or 'bash')

    def tearDown(self):
        self.temp.cleanup()

    def run_request(self, request, stdin='', exit_code=0):
        self.env['MOCK_EXIT'] = str(exit_code)
        # No profile or external shell setup participates in these tests.
        flags = ['-f', '-c'] if Path(self.shell).name == 'zsh' else ['--noprofile','--norc','-c']
        script = 'source ' + shlex.quote(str(ROOT / '.bash_aliases')) + '\n' + request
        p = subprocess.run([self.shell,*flags,script], input=stdin, text=True,
                           cwd=self.base, env=self.env, capture_output=True, timeout=10)
        record = json.loads(self.capture.read_text()) if self.capture.exists() else None
        return p, record

    def request_words(self, record):
        # Tested cases do not need Bash's ANSI-C $'...' quote syntax.
        return shlex.split(record['stdin'].split('\nRequest:\n', 1)[1])

    def test_unquoted_ask(self):
        p, r = self.run_request('ask show the top 3 processes by CPU usage')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.request_words(r), ['show','the','top','3','processes','by','CPU','usage'])
        self.assertEqual(r['args'][r['args'].index('--sandbox')+1], 'read-only')

    def test_unquoted_act_and_quoted_tilde_path(self):
        p, r = self.run_request('act empty "~/my fav/big folder"')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.request_words(r), ['empty', str(self.home / 'my fav/big folder')])
        self.assertEqual(r['args'][r['args'].index('--sandbox')+1], 'danger-full-access')
        self.assertIn('no per-command approvals', p.stderr)

    def test_plain_temp_is_passed_not_interpreted_by_wrapper(self):
        p, r = self.run_request('act empty the temp')
        self.assertEqual(self.request_words(r), ['empty','the','temp'])
        self.assertIn('ambiguous, print one focused question and STOP', r['stdin'])

    def test_two_distinct_paths(self):
        p, r = self.run_request('act move "first folder" into "second folder"')
        self.assertEqual(self.request_words(r), ['move','first folder','into','second folder'])

    def test_fully_quoted_sentence(self):
        p, r = self.run_request('ask "what is in this folder?"')
        self.assertEqual(self.request_words(r), ['what is in this folder?'])

    def test_quoted_pattern_is_preserved(self):
        (self.base / 'one.tmp').touch()
        p, r = self.run_request("ask find '*.tmp' in this folder")
        self.assertEqual(self.request_words(r), ['find','*.tmp','in','this','folder'])

    def test_literal_tilde_directory_is_preserved(self):
        p, r = self.run_request('ask list "./~/my fav"')
        self.assertEqual(self.request_words(r), ['list','./~/my fav'])

    def test_shell_syntax_inside_single_quotes_is_not_evaluated(self):
        p, r = self.run_request("ask 'explain $(touch SHOULD_NOT_EXIST); echo danger'")
        self.assertFalse((self.base / 'SHOULD_NOT_EXIST').exists())
        self.assertEqual(self.request_words(r), ['explain $(touch SHOULD_NOT_EXIST); echo danger'])

    def test_raw_mode_preserves_quotes_metacharacters_and_unicode(self):
        raw = '''empty "~/my fav/big folder"; don't run $(touch BAD) & keep café\n'''
        p, r = self.run_request('act', stdin=raw)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('Input format: Raw English text.', r['stdin'])
        self.assertEqual(r['stdin'].split('\nRequest:\n',1)[1], raw)
        self.assertFalse((self.base / 'BAD').exists())

    def test_ask_host_is_explicit_and_warns(self):
        p, r = self.run_request('ask --host show processes')
        self.assertEqual(r['args'][r['args'].index('--sandbox')+1], 'danger-full-access')
        self.assertIn('NOT enforced', p.stderr)
        self.assertEqual(self.request_words(r), ['show','processes'])

    def test_host_raw_mode(self):
        p, r = self.run_request('ask --host', stdin='show Windows processes\n')
        self.assertIn('show Windows processes', r['stdin'])
        self.assertIn('NOT enforced', p.stderr)

    def test_double_dash_ends_option_parsing(self):
        p, r = self.run_request('ask -- --host is an option')
        self.assertEqual(r['args'][r['args'].index('--sandbox')+1], 'read-only')
        self.assertEqual(self.request_words(r), ['--host','is','an','option'])

    def test_credentials_are_removed_only_for_child(self):
        p, r = self.run_request('ask show disk space; printf "PARENT=%s/%s\\n" "$OPENAI_API_KEY" "$CODEX_API_KEY"')
        self.assertIsNone(r['openai_key'])
        self.assertIsNone(r['codex_key'])
        self.assertIn('PARENT=test-api-marker/test-codex-marker', p.stdout)
        self.assertIn('forced_login_method=chatgpt', r['args'])
        self.assertIn('model_provider=openai', r['args'])

    def test_exit_code_is_propagated(self):
        p, r = self.run_request('ask show disk space', exit_code=17)
        self.assertEqual(p.returncode, 17)

    def test_native_executable_is_used_even_with_a_shadowing_function(self):
        p, r = self.run_request('codex() { return 99; }; ask show disk space')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.request_words(r), ['show', 'disk', 'space'])

    def test_missing_native_executable_fails_without_path_fallback(self):
        (self.bin / 'codex').unlink()
        for mode in ('ask', 'act'):
            with self.subTest(mode=mode):
                p, r = self.run_request(f'{mode} show disk space')
                self.assertEqual(p.returncode, 127, p.stderr)
                self.assertIn('Native Codex executable not found:', p.stderr)
                self.assertIsNone(r)

    def test_blank_raw_request_does_not_call_codex(self):
        p, r = self.run_request('act', stdin='   \n')
        self.assertEqual(p.returncode, 2)
        self.assertIsNone(r)

    def test_eof_does_not_call_codex(self):
        p, r = self.run_request('ask')
        self.assertEqual(p.returncode, 2)
        self.assertIsNone(r)

    def test_help_does_not_call_codex(self):
        p, r = self.run_request('act --help')
        self.assertEqual(p.returncode, 0)
        self.assertIsNone(r)

    def test_cwd_and_stdin_prompt_mode(self):
        p, r = self.run_request('ask free disk space')
        self.assertEqual(p.returncode, 0)
        self.assertEqual(r['cwd'], str(self.base))
        self.assertEqual(r['args'][-1], '-')


    def test_all_help_spellings_have_complete_mode_specific_usage(self):
        for mode in ('ask', 'act'):
            for flag in ('--help', '-h'):
                with self.subTest(mode=mode, flag=flag):
                    p, r = self.run_request(f'{mode} {flag}')
                    self.assertEqual(p.returncode, 0, p.stderr)
                    self.assertIsNone(r)
                    self.assertEqual(p.stderr, '')
                    self.assertTrue(p.stdout.startswith(mode + ' - '))
                    self.assertIn(f'  {mode} [--host] [--] [request ...]', p.stdout)
                    for section in ('USAGE', 'EXAMPLES', 'OPTIONS', 'PERMISSIONS',
                                    'INPUT AND QUOTING', 'RAW INPUT', 'SETUP',
                                    'OUTPUT AND STATUS'):
                        self.assertIn(section, p.stdout)
                    for phrase in ('ChatGPT', 'codex login', 'no Codex', '~/my fav/big folder'):
                        self.assertIn(phrase, p.stdout)
                    self.assertIn('read-only' if mode == 'ask' else 'NO per-command', p.stdout)

    def test_help_after_host_option_does_not_call_codex(self):
        for mode in ('ask', 'act'):
            for flag in ('--help', '-h'):
                with self.subTest(mode=mode, flag=flag):
                    p, r = self.run_request(f'{mode} --host {flag}')
                    self.assertEqual(p.returncode, 0, p.stderr)
                    self.assertIsNone(r)
                    self.assertEqual(p.stderr, '')
                    self.assertIn('USAGE', p.stdout)

    def test_help_requires_no_executables_on_path(self):
        # Keep the parent PATH so Python can launch the shell; remove it INSIDE.
        for mode in ('ask', 'act'):
            with self.subTest(mode=mode):
                p, r = self.run_request(f'PATH=/nonexistent; {mode} --help')
                self.assertEqual(p.returncode, 0, p.stderr)
                self.assertIsNone(r)
                self.assertEqual(p.stderr, '')
                self.assertIn('SETUP', p.stdout)

    def test_help_does_not_consume_stdin(self):
        p, r = self.run_request('act -h >/dev/null; IFS= read -r line; printf "UNREAD=%s\\n" "$line"',
                                stdin='preserved input\n')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIsNone(r)
        self.assertIn('UNREAD=preserved input', p.stdout)

    def test_help_does_not_change_credentials(self):
        p, r = self.run_request('ask -h >/dev/null; printf "PARENT=%s/%s\\n" "$OPENAI_API_KEY" "$CODEX_API_KEY"')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIsNone(r)
        self.assertIn('PARENT=test-api-marker/test-codex-marker', p.stdout)

    def test_help_output_is_redirectable(self):
        p, r = self.run_request('act --help > help.txt')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIsNone(r)
        self.assertEqual(p.stdout, '')
        self.assertEqual(p.stderr, '')
        self.assertIn('act - perform changes', (self.base / 'help.txt').read_text())

    def test_help_ignores_following_task_text_without_execution(self):
        p, r = self.run_request('act --help empty ./temp')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIsNone(r)
        self.assertIn('USAGE', p.stdout)

    def test_help_after_words_is_not_a_wrapper_option(self):
        p, r = self.run_request('ask explain --help and -h')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.request_words(r), ['explain', '--help', 'and', '-h'])

    def test_double_dash_preserves_help_as_task_text(self):
        p, r = self.run_request('ask -- --help -h')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.request_words(r), ['--help', '-h'])

    def test_help_is_idempotent_and_leaves_following_calls_working(self):
        p, r = self.run_request('ask -h >/dev/null; act --help >/dev/null; ask show disk space')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.request_words(r), ['show', 'disk', 'space'])
        self.assertEqual(r['args'][r['args'].index('--sandbox') + 1], 'read-only')

    def test_help_works_under_nounset(self):
        p, r = self.run_request('set -u; ask -h')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIsNone(r)
        self.assertIn('USAGE', p.stdout)

    def test_help_flags_do_not_change_task_execution_options(self):
        p, r = self.run_request('act empty ./temp')
        self.assertEqual(p.returncode, 0, p.stderr)
        expected = ['exec', '--cd', str(self.base), '--skip-git-repo-check', '--ephemeral',
                    '--sandbox', 'danger-full-access', '-c', 'approval_policy=never',
                    '-c', 'model_provider=openai', '-c', 'forced_login_method=chatgpt',
                    '-c', 'hide_agent_reasoning=true', '-c', 'features.apps=false', '-']
        self.assertEqual(r['args'], expected)

if __name__ == '__main__':
    unittest.main(verbosity=2)
