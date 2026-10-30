"""Exercise wrapper boundaries without real credentials, Docker, or sbx."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[3]


class SubscriptionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / 'home'
        self.work = self.root / 'work'
        self.work.mkdir()
        (self.home / '.claude').mkdir(parents=True)
        private = self.home / '.local/state/sbx-agent-credentials'
        private.mkdir(parents=True)
        self.token = private / 'account2.token'
        self.token.write_text('sk-ant-oat01-TEST-ONLY\n')
        self.token.chmod(0o600)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        sbx = self.bin / 'sbx'
        sbx.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['CALLS'], 'a') as f: f.write(json.dumps(sys.argv[1:])+'\\n')
a=sys.argv[1:]
if a == ['secret','ls']:
 print('SCOPE SERVICE SECRET')
 if os.environ.get('GLOBAL'): print('(global) anthropic (oauth configured)')
elif a == ['ls']:
 print('NAME STATUS')
 if os.environ.get('EXISTS'): print('test running')
elif a[:2] == ['secret','set']:
 value=sys.stdin.read()
 if value != 'sk-ant-oat01-TEST-ONLY': sys.exit(2)
 if os.environ.get('FAIL_SECRET'): sys.exit(3)
elif a and a[0] == 'exec': sys.exit(97)
''')
        sbx.chmod(0o755)
        self.env = {**os.environ, 'HOME': str(self.home),
                    'PATH': str(self.bin) + ':' + os.environ['PATH'],
                    'DOTFILES_DIR': str(REPO), 'CALLS': str(self.root / 'calls')}
        for key in ('GLOBAL', 'EXISTS', 'FAIL_SECRET', 'SBX_AGENT_MOUNTS'):
            self.env.pop(key, None)

    def run_wrapper(self, *extra):
        return subprocess.run(['bash', str(REPO / 'local/bin/sbx-agent'),
                               'claude', '--claude-account', 'account2',
                               '--name', 'test', '--no-host-bridge',
                               '--workspace', str(self.work), *extra],
                              env=self.env, capture_output=True, text=True)

    def calls(self):
        return [json.loads(x) for x in (self.root / 'calls').read_text().splitlines()]

    def test_create_and_reuse(self):
        result = self.run_wrapper('--', 'hello world')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        create = next(c for c in calls if c[0] == 'create')
        self.assertIn(str(REPO / 'config/sbx/claude-subscription'), create)
        self.assertLess(next(i for i,c in enumerate(calls) if c[:2] == ['secret','set']), calls.index(create))
        self.assertEqual(calls[-1], ['run', '--name', 'test', '--', 'hello world'])
        self.assertNotIn('sk-ant-oat01-TEST-ONLY', result.stdout + result.stderr + json.dumps(calls))
        self.env['EXISTS'] = '1'
        self.assertEqual(self.run_wrapper().returncode, 0)

    def test_new_removes_before_registering(self):
        self.env['EXISTS'] = '1'
        result = self.run_wrapper('--new')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        remove = next(i for i,c in enumerate(calls) if c[0] == 'rm')
        register = next(i for i,c in enumerate(calls) if c[:2] == ['secret','set'])
        self.assertLess(remove, register)

    def test_missing_token_stops(self):
        self.token.unlink()
        self.assertNotEqual(self.run_wrapper().returncode, 0)
        self.assertFalse((self.root / 'calls').exists())

    def test_other_account_marker_stops(self):
        marker = self.token.parent / 'sandboxes/test'
        marker.parent.mkdir()
        marker.write_text('work3\n')
        self.env['EXISTS'] = '1'
        self.assertNotEqual(self.run_wrapper().returncode, 0)
        self.assertFalse(any(c[0] == 'run' for c in self.calls()))

    def test_global_stops_before_registration(self):
        self.env['GLOBAL'] = '1'
        self.assertNotEqual(self.run_wrapper().returncode, 0)
        self.assertFalse(any(c[:2] == ['secret','set'] for c in self.calls()))

    def test_untracked_existing_stops(self):
        self.env['EXISTS'] = '1'
        self.assertNotEqual(self.run_wrapper().returncode, 0)
        self.assertFalse(any(c[0] == 'run' for c in self.calls()))

    def test_registration_failure_stops(self):
        self.env['FAIL_SECRET'] = '1'
        self.assertNotEqual(self.run_wrapper().returncode, 0)
        self.assertFalse(any(c[0] in ('create','run') for c in self.calls()))

    def test_exposed_token_directory_stops(self):
        self.assertNotEqual(self.run_wrapper('--mount', str(self.home)).returncode, 0)
        self.assertFalse(any(c[:2] == ['secret','set'] for c in self.calls()))

    def test_unsafe_permissions_stop(self):
        self.token.chmod(0o644)
        self.assertNotEqual(self.run_wrapper().returncode, 0)
        self.assertFalse(any(c[0] in ('create','run') for c in self.calls()))

    def test_settings_override_stops(self):
        (self.home / '.claude/settings.json').write_text('{"apiKeyHelper":"echo other"}')
        self.assertNotEqual(self.run_wrapper().returncode, 0)
        self.assertFalse(any(c[0] in ('create','run') for c in self.calls()))


if __name__ == '__main__':
    unittest.main()
