"""Account boundaries and host service contracts; no real sandbox or service is started."""
import argparse
import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / "local/bin/t3-sandbox"
loader = importlib.machinery.SourceFileLoader("t3_sandbox", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
app = importlib.util.module_from_spec(spec)
with patch.object(sys, "dont_write_bytecode", True):
    loader.exec_module(app)


class SandboxTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="t3-sandbox-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / "home"
        self.workspace = self.root / 'project with "quotes" and spaces'
        self.workspace.mkdir()
        environment = {"XDG_STATE_HOME": str(self.root / "state"),
                       "XDG_DATA_HOME": str(self.root / "data"),
                       "XDG_CONFIG_HOME": str(self.root / "config")}
        for mock in (patch.dict(os.environ, environment), patch.object(Path, "home", return_value=self.home),
                     patch.object(app, "require"), patch.object(app, "run", side_effect=self.fake_run),
                     patch.object(app, "install_service")):
            mock.start()
            self.addCleanup(mock.stop)
        self.calls = []
        self.fail = None
        for account in app.ACCOUNTS:
            token = self.home / ".local/state/sbx-agent-credentials" / f"{account}.token"
            token.parent.mkdir(parents=True, exist_ok=True)
            token.write_text("test-token-never-read")

    def fake_run(self, args, **kwargs):
        args = list(map(str, args))
        self.calls.append(args)
        if args[0] == self.fail:
            raise subprocess.CalledProcessError(9, args)
        return subprocess.CompletedProcess(args, 0, stdout=str(self.workspace) + "\n")

    def setup_account(self, account="account2", **kwargs):
        args = argparse.Namespace(account=account, workspace=str(self.workspace), port=None, no_autostart=False)
        vars(args).update(kwargs)
        with contextlib.redirect_stdout(io.StringIO()):
            app.setup(args)
        return app.load_profile(account)

    def test_account_selection_passes_subscription_and_matching_config(self):
        profile = self.setup_account()
        command = next(c for c in self.calls if c[0] == "sbx-agent")
        self.assertEqual(command[1:4], ["claude", "--claude-account", "account2"])
        self.assertEqual(command[command.index("--config-dir") + 1], str(self.home / ".claude-account2"))
        self.assertEqual(command[command.index("--name") + 1], "t3-account2")
        self.assertEqual(command[command.index("--publish") + 1], "3774:3773")
        self.assertNotIn("--new", command)
        self.assertEqual(profile["workspace"], str(self.workspace))
        app.install_service.assert_called_once_with(profile)

    def test_accounts_have_separate_data_sandboxes_and_ports(self):
        first, second = self.setup_account("account1"), self.setup_account("work3")
        for key in ("storage", "name", "port"):
            self.assertNotEqual(first[key], second[key])
        self.assertEqual(app.load_profile("account1"), first)

    def test_new_threads_default_to_worktrees_and_data_is_mounted(self):
        profile = self.setup_account()
        settings = Path(profile["storage"]) / "t3/userdata/settings.json"
        self.assertEqual(json.loads(settings.read_text())["defaultThreadEnvMode"], "worktree")
        command = next(c for c in self.calls if c[0] == "sbx-agent")
        self.assertEqual(command[command.index("--mount") + 1], profile["storage"])
        self.assertFalse(app.profile_path("account2").is_relative_to(Path(profile["storage"])))
        self.assertNotIn("test-token", app.profile_path("account2").read_text())

    def test_repeat_setup_preserves_settings_and_history(self):
        profile = self.setup_account()
        settings = Path(profile["storage"]) / "t3/userdata/settings.json"
        settings.write_text('{"defaultThreadEnvMode":"worktree","theme":"custom"}')
        history = settings.parent / "history.db"
        history.write_bytes(b"existing history")
        self.setup_account()
        self.assertEqual(json.loads(settings.read_text())["theme"], "custom")
        self.assertEqual(history.read_bytes(), b"existing history")

    def test_changed_port_does_not_rebind_existing_account(self):
        previous = self.setup_account()
        self.calls.clear()
        with self.assertRaisesRegex(ValueError, "設定済み"):
            self.setup_account(port=9999)
        self.assertEqual(app.load_profile("account2"), previous)
        self.assertFalse(any(call[0] in ("sbx", "sbx-agent") for call in self.calls))

    def test_missing_token_fails_before_sandbox_commands(self):
        (self.home / ".local/state/sbx-agent-credentials/account2.token").unlink()
        with self.assertRaisesRegex(ValueError, "未登録"):
            self.setup_account()
        self.assertFalse(self.calls)

    def test_symlink_token_is_rejected(self):
        token = self.home / ".local/state/sbx-agent-credentials/account2.token"
        token.unlink()
        token.symlink_to(self.home / ".local/state/sbx-agent-credentials/account1.token")
        with self.assertRaisesRegex(ValueError, "未登録"):
            self.setup_account()
        self.assertFalse(self.calls)

    def test_failed_prepare_never_registers_service_or_profile(self):
        self.fail = "sbx-agent"
        with self.assertRaises(subprocess.CalledProcessError):
            self.setup_account()
        self.assertFalse(app.profile_path("account2").exists())
        app.install_service.assert_not_called()

    def test_failed_sbx_probe_does_not_create_data(self):
        self.fail = "sbx"
        with self.assertRaises(subprocess.CalledProcessError):
            self.setup_account()
        self.assertFalse((self.root / "data").exists())
        app.install_service.assert_not_called()

    def test_cli_preserves_arguments_without_host_shell_expansion(self):
        profile = self.setup_account()
        payload = '$(touch /tmp/unexpected); "quoted"'
        command = app.t3_command(profile, ["pair", "--label", payload])
        self.assertEqual(command[:5], ["sbx", "exec", "-u", "agent", "t3-account2"])
        self.assertEqual(command[-3:], ["pair", "--label", payload])
        self.assertIn('cd "$1" || exit 1', command[7])
        self.assertEqual(command[9], str(self.workspace))

    def test_interactive_account_selection(self):
        with patch.object(app.sys.stdin, "isatty", return_value=True), patch("builtins.input", return_value="3"), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(app.choose_account(), "work3")

    def test_noninteractive_setup_requires_explicit_account(self):
        with patch.object(app.sys.stdin, "isatty", return_value=False):
            with self.assertRaisesRegex(ValueError, "--account"):
                app.choose_account()

    def test_no_autostart_is_explicit_opt_out(self):
        self.setup_account(no_autostart=True)
        app.install_service.assert_not_called()

    def test_service_runner_executes_only_in_selected_sandbox(self):
        profile = self.setup_account()
        self.calls.clear()
        with patch.object(app.sys, "argv", [str(SCRIPT), "run", "account2"]), patch.object(app.os, "execvp") as execute:
            app.main()
        command = execute.call_args.args[1]
        self.assertEqual(command[0:5], ["sbx", "exec", "-u", "agent", "t3-account2"])
        self.assertIn("--no-browser", command)
        self.assertIn("--auto-bootstrap-project-from-cwd", command)
        self.assertEqual(command[10], str(Path(profile["storage"]) / "t3"))

    def test_service_runner_does_not_exec_when_prepare_fails(self):
        self.setup_account()
        self.fail = "sbx-agent"
        with patch.object(app.sys, "argv", [str(SCRIPT), "run", "account2"]), patch.object(app.os, "execvp") as execute:
            with self.assertRaises(subprocess.CalledProcessError):
                app.main()
        execute.assert_not_called()


class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='t3-service "quotes"-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for mock in (patch.object(Path, "home", return_value=self.root),
                     patch.dict(os.environ, {"XDG_STATE_HOME": str(self.root / "state"), "XDG_CONFIG_HOME": str(self.root / "config")}),
                     patch.object(app, "require")):
            mock.start()
            self.addCleanup(mock.stop)
        self.profile = {"account": "account2"}

    def test_launchagent_persists_account_and_starts_at_login(self):
        with patch.object(app.sys, "platform", "darwin"), patch.object(app, "run") as call, patch.object(app.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)):
            app.install_service(self.profile)
        path = self.root / "Library/LaunchAgents/local.t3-sandbox.account2.plist"
        service = plistlib.loads(path.read_bytes())
        self.assertEqual(service["ProgramArguments"][-2:], ["run", "account2"])
        self.assertTrue(service["KeepAlive"])
        self.assertTrue(service["RunAtLoad"])
        self.assertEqual(call.call_args.args[0][1], "bootstrap")

    def test_registered_launchagent_is_not_restarted(self):
        with patch.object(app.sys, "platform", "darwin"), patch.object(app, "run") as call, patch.object(app.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)), contextlib.redirect_stdout(io.StringIO()):
            app.install_service(self.profile)
        call.assert_not_called()

    def test_systemd_unit_starts_account_runner_without_shell(self):
        with patch.object(app.sys, "platform", "linux"), patch.object(app, "run") as call:
            app.install_service(self.profile)
        path = self.root / "config/systemd/user/local.t3-sandbox.account2.service"
        unit = path.read_text()
        self.assertIn('"run" "account2"', unit)
        self.assertIn("Restart=always", unit)
        self.assertNotIn("bash -c", unit)
        self.assertEqual(call.call_args.args[0][2:4], ["enable", "--now"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
