import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

loader = importlib.machinery.SourceFileLoader(
    'watcher', str(Path(__file__).resolve().parents[2] / 'local/bin/pr-author-fix'))
spec = importlib.util.spec_from_loader(loader.name, loader)
w = importlib.util.module_from_spec(spec)
loader.exec_module(w)


class WatcherTest(unittest.TestCase):
    def test_detect_origin_without_an_agent_option(self):
        for environment, expected in (
            ({'CLAUDECODE': '1'}, 'claude'),
            ({'CLAUDE_CODE_ENTRYPOINT': 'cli'}, 'claude'),
            ({'CODEX_THREAD_ID': 'thread'}, 'codex'),
        ):
            with self.subTest(environment=environment), patch.dict(
                    w.os.environ, environment, clear=True), patch.object(w, 'run') as run:
                self.assertEqual(w.detect_agent(), expected)
                run.assert_not_called()

    def test_detect_nearest_ancestor_and_reject_unknown_origin(self):
        with patch.dict(w.os.environ, {}, clear=True), patch.object(
                w.os, 'getppid', return_value=20), patch.object(
                w, 'run', return_value='20 10 bash\n10 1 /usr/bin/copilot\n'):
            self.assertEqual(w.detect_agent(), 'copilot')
        with patch.dict(w.os.environ, {}, clear=True), patch.object(
                w.os, 'getppid', return_value=20), patch.object(
                w, 'run', return_value='20 1 bash\n'):
            with self.assertRaisesRegex(ValueError, '起動元 AI'):
                w.detect_agent()

    def test_claude_child_does_not_inherit_nested_session_guard(self):
        with patch.dict(w.os.environ, {'CLAUDECODE': '1', 'PATH': '/bin'}, clear=True), patch.object(
                w.subprocess, 'run') as run:
            w.invoke_agent('claude', 'fix reviews')
            command = run.call_args.args[0]
            self.assertEqual(command, ['claude', '-p', 'fix reviews'])
            self.assertNotIn('CLAUDECODE', run.call_args.kwargs['env'])
            self.assertEqual(w.os.environ['CLAUDECODE'], '1')

    def test_filter_and_edit_detection(self):
        items = [dict(id=1, user={'login': 'me'}, body='self'),
                 dict(id=2, user={'login': 'bot'}, body='**AIによる返信**\n\nfixed'),
                 dict(id=3, user={'login': 'reviewer'}, body='fix this')]
        with patch.object(w, 'api', return_value=items):
            first = w.feedback('owner/repo', 1, 'me')
            self.assertEqual(len(first), 3)  # one external comment per endpoint
            items[2]['body'] = 'updated feedback'
            self.assertNotEqual(first, w.feedback('owner/repo', 1, 'me'))

    def test_idle_success_failure_and_new_feedback(self):
        pulls = [dict(number=1, user={'login': 'me'}, html_url='https://example/1'),
                 dict(number=2, user={'login': 'other'}, html_url='https://example/2')]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'state.json'
            state = {}
            with patch.object(w, 'api', return_value=pulls), patch.object(
                    w, 'feedback', return_value={'inline:1': 'v1'}), patch.object(
                    w.subprocess, 'run') as agent:
                agent.side_effect = subprocess.CalledProcessError(1, 'codex')
                with self.assertRaises(subprocess.CalledProcessError):
                    w.poll('owner/repo', 'me', state, path, 'codex')
                self.assertEqual(state, {})
                self.assertFalse(path.exists())
                agent.side_effect = None
                w.poll('owner/repo', 'me', state, path, 'codex')
                agent.reset_mock()
                w.poll('owner/repo', 'me', state, path, 'codex')
                agent.assert_not_called()
                self.assertEqual(state, {'1': {'inline:1': 'v1'}})
            with patch.object(w, 'api', return_value=pulls), patch.object(
                    w, 'feedback', return_value={'inline:1': 'v2'}), patch.object(
                    w.subprocess, 'run') as agent:
                w.poll('owner/repo', 'me', state, path, 'claude')
                agent.assert_called_once()
                self.assertEqual(state['1']['inline:1'], 'v2')


if __name__ == '__main__':
    unittest.main()
