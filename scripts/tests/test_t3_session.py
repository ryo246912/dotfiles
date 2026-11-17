import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / 'local/bin/t3-session'


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='t3-test-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.repo = self.base / 'project with spaces'
        self.repo.mkdir()
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.log = self.base / 'calls.jsonl'
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}', CALL_LOG=str(self.log))
        self.git('init', '-q')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', 'Test')
        self.git('config', 'core.hooksPath', '/dev/null')
        (self.repo / 'source').write_text('original\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'initial')
        stub = '''#!/usr/bin/env python3
import json, os, pathlib, sys
with open(os.environ['CALL_LOG'], 'a') as f:
    f.write(json.dumps([pathlib.Path(sys.argv[0]).name] + sys.argv[1:]) + '\\n')
if sys.argv[1:2] == ['ls'] and os.environ.get('FAIL_SBX'):
    sys.exit(9)
if pathlib.Path(sys.argv[0]).name == 'sbx-agent' and os.environ.get('FAIL_AGENT'):
    sys.exit(8)
'''
        for name in ('sbx', 'sbx-agent'):
            path = self.bin / name
            path.write_text(stub)
            path.chmod(0o755)

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], env=self.env, text=True).strip()

    def run_session(self, *args, success=True, env=None):
        result = subprocess.run([str(SCRIPT), *args], cwd=self.repo, env=env or self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return result

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def worktree(self):
        return next((self.base / 'worktrees').iterdir())

    def test_new_session_isolates_changes_and_runs_inside_sbx(self):
        (self.repo / 'source').write_text('uncommitted\n')
        self.run_session('start', 'fix-login', 'HEAD')
        wt = self.worktree()
        self.assertEqual((wt / 'source').read_text(), 'original\n')
        self.assertEqual((self.repo / 'source').read_text(), 'uncommitted\n')
        self.assertEqual(subprocess.check_output(['git', '-C', str(wt), 'branch', '--show-current'], text=True).strip(), 't3/fix-login')
        calls = self.calls()
        setup = next(c for c in calls if c[0] == 'sbx-agent')
        self.assertEqual(setup[setup.index('--workspace') + 1], str(wt))
        self.assertIn('--setup-only', setup)
        self.assertEqual(calls[-1][1:4], ['exec', '-u', 'agent'])
        self.assertIn('--auto-bootstrap-project-from-cwd', calls[-1][-3])
        self.assertEqual(calls[-1][-1], str(wt))

    def test_resume_preserves_session_changes_and_identity(self):
        self.run_session('start', 'fix-login')
        wt = self.worktree()
        (wt / 'source').write_text('session edit\n')
        initial = self.calls()[-1][4]
        self.run_session('start', 'fix-login')
        self.assertEqual(initial, self.calls()[-1][4])
        self.assertEqual((wt / 'source').read_text(), 'session edit\n')
        self.assertEqual(len(list((self.base / 'worktrees').iterdir())), 1)

    def test_separate_sessions_have_separate_sandboxes_and_worktrees(self):
        self.run_session('start', 'one')
        self.run_session('start', 'two')
        setups = [c for c in self.calls() if c[0] == 'sbx-agent']
        self.assertNotEqual(setups[0][setups[0].index('--name') + 1], setups[1][setups[1].index('--name') + 1])
        self.assertEqual(len(list((self.base / 'worktrees').iterdir())), 2)

    def test_daemon_failure_creates_nothing(self):
        self.run_session('start', 'fail', success=False, env=dict(self.env, FAIL_SBX='1'))
        self.assertFalse((self.base / 'worktrees').exists())
        self.assertEqual(len(self.calls()), 1)

    def test_setup_failure_preserves_worktree_without_running_t3(self):
        self.run_session('start', 'fail', success=False, env=dict(self.env, FAIL_AGENT='1'))
        self.assertTrue(self.worktree().exists())
        self.assertFalse(any(c[1:2] == ['exec'] for c in self.calls()))

    def test_cli_arguments_do_not_expand_on_host(self):
        self.run_session('start', 'one')
        payload = f'$(touch {self.base}/unexpected)'
        self.run_session('cli', 'one', 'pair', '--label', payload)
        self.assertEqual(self.calls()[-1][-3:], ['pair', '--label', payload])
        self.assertFalse((self.base / 'unexpected').exists())

    def test_invalid_names_are_rejected_before_side_effects(self):
        for name in ('../bad', '-bad', 'bad-', 'Bad', 'a' * 33):
            self.run_session('start', name, success=False)
        self.assertFalse(self.log.exists())

    def test_existing_branch_is_not_replaced(self):
        self.git('branch', 't3/one')
        self.run_session('start', 'one', success=False)
        self.assertFalse(any(c[0] == 'sbx-agent' for c in self.calls()))

    def test_unknown_ref_does_not_create_worktree(self):
        self.run_session('start', 'one', 'missing-ref', success=False)
        self.assertFalse((self.base / 'worktrees').exists())

    def test_resume_with_base_is_rejected(self):
        self.run_session('start', 'one')
        count = len([c for c in self.calls() if c[0] == 'sbx-agent'])
        self.run_session('start', 'one', 'HEAD', success=False)
        self.assertEqual(count, len([c for c in self.calls() if c[0] == 'sbx-agent']))

    def test_stop_keeps_worktree(self):
        self.run_session('start', 'one')
        self.run_session('stop', 'one')
        self.assertEqual(self.calls()[-1][1], 'stop')
        self.assertTrue((self.worktree() / 'source').exists())

    def test_existing_path_from_other_repo_is_rejected(self):
        self.run_session('start', 'one')
        wt = self.worktree()
        self.git('worktree', 'remove', str(wt))
        wt.mkdir()
        subprocess.run(['git', 'init', '-q', str(wt)], check=True)
        self.run_session('start', 'one', success=False)


if __name__ == '__main__':
    unittest.main(verbosity=2)
