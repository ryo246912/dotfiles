"""Exercise sbx-agent's two creation paths without a daemon or real credentials."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class EnvironmentBackendTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.workspace = self.root / 'workspace with spaces'
        self.workspace.mkdir()
        self.base = self.root / 'base.yaml'
        self.base.write_text('schemaVersion: "1"\nagent: claude\n')
        bin_dir = self.root / 'bin'
        bin_dir.mkdir()
        mock = bin_dir / 'sbx'
        mock.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
root = pathlib.Path(os.environ['TEST_ROOT'])
with (root/'calls').open('a') as f:
    f.write(json.dumps(args)+'\\n')
if args == ['version']:
    print('sbx version v'+os.environ.get('TEST_VERSION','0.50.1')+' test')
elif args == ['ls']:
    print('NAME AGENT')
    if os.environ.get('TEST_EXISTS'): print('test claude')
elif args[:2] in [['env','create'], ['env','plan']]:
    (root/'overlay.json').write_text(pathlib.Path(args[-1]).read_text())
    sys.exit(int(os.environ.get('TEST_CREATE_RC','0')))
elif args[:1] == ['run']:
    sys.exit(int(os.environ.get('TEST_RUN_RC','0')))
''')
        mock.chmod(0o755)
        self.env = {**os.environ, 'HOME': str(self.root),
                    'XDG_STATE_HOME': str(self.root/'state'),
                    'PATH': str(bin_dir)+':'+os.environ['PATH'],
                    'TEST_ROOT': str(self.root)}

    def run_agent(self, *args, env_backend=True):
        cmd = ['bash', str(ROOT/'local/bin/sbx-agent'), 'claude',
               '--name', 'test', '--workspace', str(self.workspace),
               '--no-config', '--no-host-bridge']
        if env_backend:
            cmd += ['--env-file', str(self.base)]
        return subprocess.run(cmd+list(args), env=self.env,
                              capture_output=True, text=True)

    def calls(self):
        return [json.loads(s) for s in (self.root/'calls').read_text().splitlines()]

    def test_env_create_preserves_runtime_values(self):
        mount = self.root/'mount "quoted"'; mount.mkdir()
        result = self.run_agent('--mount', str(mount)+':ro', '--cpus', '3',
                                '--memory', '8g', '--publish', '8080:3000',
                                '--env-force', '--', 'prompt with spaces')
        self.assertEqual(result.returncode, 0, result.stderr)
        overlay = json.loads((self.root/'overlay.json').read_text())
        self.assertEqual(overlay['workspace'], str(self.workspace))
        self.assertEqual(overlay['additionalWorkspaces'], [{'path': str(mount), 'readOnly': True}])
        self.assertEqual(overlay['ports'], [{'host': 8080, 'sandbox': 3000}])
        self.assertEqual(overlay['sandboxOptions'], {'template': 'sbx-agent:claude', 'pullPolicy': 'missing', 'skills': 'readonly', 'cpus': 3, 'memory': '8g'})
        self.assertEqual(overlay['env']['AI_AGENT'], '1')
        calls = self.calls()
        self.assertTrue(any(c[:2] == ['env', 'create'] and '--force' in c for c in calls))
        self.assertEqual(calls[-1], ['run', '--name', 'test', '--', 'prompt with spaces'])
        self.assertTrue(any(c[0] == 'exec' for c in calls))

    def test_legacy_stays_default(self):
        r = self.run_agent(env_backend=False)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(any(c[0] == 'create' for c in self.calls()))
        self.assertFalse(any(c[0] == 'env' for c in self.calls()))

    def test_plan_never_deletes_or_creates(self):
        self.env['TEST_EXISTS'] = '1'
        r = self.run_agent('--new', '--env-plan')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.calls()[-1][:2], ['env', 'plan'])
        self.assertFalse(any(c[0] in ('rm', 'create', 'run', 'secret') for c in self.calls()))

    def test_existing_sandbox_reused_and_initialized(self):
        self.env['TEST_EXISTS'] = '1'
        r = self.run_agent()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(any(c[:2] == ['env', 'create'] for c in self.calls()))
        self.assertTrue(any(c[0] == 'exec' for c in self.calls()))

    def test_new_and_rm_use_environment_cleanup(self):
        self.env.update(TEST_EXISTS='1', TEST_RUN_RC='7')
        r = self.run_agent('--new', '--rm')
        self.assertEqual(r.returncode, 7, r.stderr)
        self.assertEqual(sum(c[:2] == ['env', 'rm'] for c in self.calls()), 2)
        self.assertNotIn('--rm', next(c for c in self.calls() if c[0] == 'run'))

    def test_creation_failure_does_not_launch_agent(self):
        self.env['TEST_CREATE_RC'] = '1'
        r = self.run_agent()
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse(any(c[0] == 'run' for c in self.calls()))

    def test_rejects_old_version(self):
        self.env['TEST_VERSION'] = '0.48.0'
        self.assertNotEqual(self.run_agent().returncode, 0)
        self.assertFalse(any(c[0] == 'env' for c in self.calls()))

    def test_rejects_writable_environment_source(self):
        self.base = self.workspace/'sbxenv.yaml'
        self.base.write_text('schemaVersion: "1"\nagent: claude\n')
        r = self.run_agent('--env-plan')
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('mount', r.stderr)

    def test_rejects_symlink_to_writable_environment_source(self):
        source = self.workspace/'source.yaml'
        source.write_text('schemaVersion: "1"\nagent: claude\n')
        self.base.unlink()
        self.base.symlink_to(source)
        self.assertNotEqual(self.run_agent('--env-plan').returncode, 0)


if __name__ == '__main__':
    unittest.main()
