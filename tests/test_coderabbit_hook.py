"""Cross-agent PreToolUse payload and blocking regression tests (no network)."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT/'config/devcontainer/scripts/coderabbit-review.sh'


class CodeRabbitHookTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root/'.git').mkdir()
        (self.root/'.coderabbit.yaml').touch()
        bindir = self.root/'bin'
        bindir.mkdir()
        for name, code in {
            'git': '''#!/bin/bash
echo git >> "$TRACE"
case "$*" in
  'rev-parse --show-toplevel') echo "$TEST_ROOT" ;;
  'rev-parse --git-dir') echo "$TEST_ROOT/.git" ;;
  'rev-parse HEAD') echo test-head ;;
esac
''',
            'coderabbit': '''#!/bin/bash
echo coderabbit >> "$TRACE"
[[ "$*" == 'review --committed --api-key cr-test-placeholder' ]] || exit 99
echo review-result
exit "${TEST_REVIEW_RC:-0}"
''',
        }.items():
            p = bindir/name
            p.write_text(code)
            p.chmod(0o755)
        self.env = {**os.environ, 'PATH': str(bindir)+':'+os.environ['PATH'],
                    'TEST_ROOT': str(self.root), 'TRACE': str(self.root/'trace'),
                    'CODERABBIT_API_KEY': 'cr-test-placeholder'}

    def run_hook(self, payload):
        return subprocess.run(['bash', str(SCRIPT)], input=payload,
                              env=self.env, text=True, capture_output=True)

    def trace(self):
        p = self.root/'trace'
        return p.read_text() if p.exists() else ''

    def test_claude_codex_and_copilot_block_once(self):
        # Codex 0.160.1 exec_command uses cmd, shell_command uses command.
        for payload in [
            {'tool_name': 'Bash', 'tool_input': {'command': 'git push'}},
            {'tool_name': 'exec_command', 'tool_input': {'cmd': 'git push'}},
            {'tool_name': 'shell_command', 'tool_input': {'command': 'gh pr create'}},
            {'toolName': 'bash', 'toolArgs': {'command': 'cd repo && git push'}},
            {'toolName': 'bash', 'toolArgs': json.dumps({'command': 'gh pr create'})},
        ]:
            with self.subTest(payload=payload):
                (self.root/'.git/coderabbit-reviewed').unlink(missing_ok=True)
                (self.root/'trace').unlink(missing_ok=True)
                result = self.run_hook(json.dumps(payload))
                self.assertEqual(result.returncode, 2)
                self.assertIn('review-result', result.stderr)
                self.assertEqual(result.stdout, '')
                self.assertEqual(self.run_hook(json.dumps(payload)).returncode, 0)
                self.assertEqual(self.trace().count('coderabbit'), 1)

    def test_unrelated_or_invalid_input_does_nothing(self):
        for payload in ['invalid', '{}', json.dumps({'tool_input': {'cmd': 'git status'}}),
                        json.dumps({'tool_input': {'cmd': 'git pushy'}})]:
            r = self.run_hook(payload)
            self.assertEqual((r.returncode, r.stdout, r.stderr), (0, '', ''))
        self.assertEqual(self.trace(), '')

    def test_failed_review_does_not_mark_or_block(self):
        self.env['TEST_REVIEW_RC'] = '1'
        r = self.run_hook(json.dumps({'tool_input': {'cmd': 'git push'}}))
        self.assertEqual(r.returncode, 0)
        self.assertFalse((self.root/'.git/coderabbit-reviewed').exists())


if __name__ == '__main__':
    unittest.main()
