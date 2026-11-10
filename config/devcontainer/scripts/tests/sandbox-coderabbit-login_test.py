#!/usr/bin/env python3
"""Regression checks: authentication must finish without waiting for SSH EOF."""
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import time
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    'login', Path(__file__).resolve().parents[1] / 'sandbox-coderabbit-login.py',
)
login = importlib.util.module_from_spec(SPEC)
sys.dont_write_bytecode = True
SPEC.loader.exec_module(login)
URL = 'https://app.coderabbit.ai/login?redirect_uri=http%3A%2F%2F127.0.0.1%3A43210%2Fcallback'


class LoginTest(unittest.TestCase):
    def run_login(self, events, timeout='2', rc=0, keep_open=True):
        real_popen = subprocess.Popen
        code = '; '.join(f'print({json.dumps(event)!r}, flush=True)' for event in events)
        code += '; import time; time.sleep(60)' if keep_open else f'; raise SystemExit({rc})'
        children = []

        def start(command, **kwargs):
            child = real_popen([sys.executable, '-u', '-c', code], **kwargs)
            children.append(child)
            return child

        with (
            patch.object(sys, 'argv', ['login', 'test', '--timeout', timeout]),
            patch.object(login.shutil, 'which', return_value='/bin/tool'),
            patch.object(login.subprocess, 'check_output', return_value='[{"name":"test"}]'),
            patch.object(login.subprocess, 'Popen', side_effect=start),
            patch.object(login.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as run,
            patch.object(login.webbrowser, 'open', return_value=True) as browser,
            patch.object(sys, 'stdout', io.StringIO()),
        ):
            try:
                result = login.main()
            finally:
                self.assertTrue(children)
                self.assertIsNotNone(children[0].poll(), 'SSH process must be reaped')
        return result, run, browser

    def test_success_closes_ssh_without_eof(self):
        started = time.monotonic()
        result, run, browser = self.run_login([
            {'status': 'awaiting_browser_auth', 'authUrl': URL},
            {'status': 'authenticated'},
        ])
        self.assertEqual(result, 0)
        self.assertLess(time.monotonic() - started, 2)
        browser.assert_called_once_with(URL)
        self.assertTrue(any('forward' in call.args[0] for call in run.call_args_list))
        self.assertTrue(any('exit' in call.args[0] for call in run.call_args_list))

    def test_authenticated_boolean_also_finishes(self):
        self.assertEqual(self.run_login([{'authenticated': True}])[0], 0)

    def test_silent_ssh_times_out(self):
        with self.assertRaisesRegex(ValueError, 'タイムアウト'):
            self.run_login([{'status': 'starting_login'}], timeout='0.1')

    def test_failure_event_cleans_up(self):
        with self.assertRaisesRegex(ValueError, 'failed'):
            self.run_login([{'type': 'error', 'message': 'failed'}])

    def test_eof_is_not_success(self):
        with self.assertRaisesRegex(ValueError, '認証成功'):
            self.run_login([{'status': 'starting_login'}], keep_open=False)

    def test_cli_failure_exit_is_preserved(self):
        self.assertEqual(self.run_login([{'status': 'starting_login'}], rc=7, keep_open=False)[0], 7)

    def test_callback_validation(self):
        self.assertEqual(login.callback_forward(URL), '127.0.0.1:43210:127.0.0.1:43210')
        for url in [URL.replace('app.coderabbit.ai', 'example.com'), URL.replace('127.0.0.1', 'example.com')]:
            with self.assertRaises(ValueError):
                login.callback_forward(url)


if __name__ == '__main__':
    unittest.main()
