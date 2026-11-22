import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / 'local/bin/sbx-agent'
HELPER = SCRIPT.read_text().split('materialize_git_config() {', 1)[1].split(
    '\nprepare_env_files() {', 1
)[0]


class GitConfigSnapshotTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.source = self.home / '.config/git'
        self.source.mkdir(parents=True)
        self.dest = self.home / 'state/git'
        for name in ('config', 'gitignore', 'attributes'):
            (self.source / name).write_text('original\n')

    def stage(self, prefix=''):
        return subprocess.run(
            ['bash', '-uc', 'log_error() { echo "$1" >&2; }\n'
             + 'materialize_git_config() {' + HELPER + '\n'
             + prefix + '\nmaterialize_git_config "$1"', 'test', str(self.dest)],
            env={**os.environ, 'HOME': str(self.home)},
            capture_output=True, text=True, timeout=10,
        )

    def test_source_replacement_and_refresh_preserve_directory(self):
        target = self.home / 'tracked-config'
        target.write_text('[user]\nname = Before\n')
        (self.source / 'config').unlink()
        (self.source / 'config').symlink_to(target)
        (self.source / 'secret').write_text('not mounted')
        self.assertEqual(self.stage().returncode, 0)
        inode = self.dest.stat().st_ino
        replacement = self.home / 'replacement'
        replacement.write_text('[user]\nname = After\n')
        replacement.replace(target)
        self.assertIn('Before', (self.dest / 'config').read_text())
        self.assertFalse((self.dest / 'config').is_symlink())
        self.assertFalse((self.dest / 'secret').exists())
        self.assertEqual(self.stage().returncode, 0)
        self.assertEqual(self.dest.stat().st_ino, inode)
        self.assertIn('After', (self.dest / 'config').read_text())

    def test_missing_and_dangling_sources_remove_old_copies(self):
        self.assertEqual(self.stage().returncode, 0)
        (self.source / 'gitignore').unlink()
        (self.source / 'attributes').unlink()
        (self.source / 'attributes').symlink_to(self.home / 'missing')
        self.assertEqual(self.stage().returncode, 0)
        self.assertEqual({p.name for p in self.dest.iterdir()}, {'config'})

    def test_copy_failure_keeps_previous_snapshot(self):
        self.assertEqual(self.stage().returncode, 0)
        (self.source / 'config').write_text('changed\n')
        result = self.stage('cp() { return 1; }')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.dest / 'config').read_text(), 'original\n')
        self.assertEqual(list(self.dest.parent.iterdir()), [self.dest])

    def test_overlay_mounts_only_snapshot_and_honors_no_config(self):
        env_file = self.home / 'sbxenv.yaml'
        env_file.write_text('schemaVersion: "1"\n')
        functions = SCRIPT.read_text().split('assert_env_path_unmounted() {', 1)[1].split(
            '\nprepare_env_files\n', 1
        )[0]
        for enabled in ('true', 'false'):
            result = subprocess.run(
                ['bash', '-uc', 'log_info() { :; }; log_error() { echo "$1" >&2; }; '
                 'expand_tilde() { printf "%s" "$1"; }; '
                 'sbx() { echo "sbx version 0.55.0"; }; '
                 'assert_env_path_unmounted() {' + functions + '\n'
                 'SANDBOX_NAME=test; WORKSPACE="$HOME/work"; MOUNTS=(); '
                 'ENV_ARGS=(); PUBLISH_PORTS=(); SUBSCRIPTION_KIT=""; '
                 'CLAUDE_PROJECTS_HOST=""; HOST_BRIDGE=false; TEMPLATE=""; '
                 'SKILLS=readonly; CPUS=""; MEMORY=""; AGENT=shell; '
                 'ENV_FILE="$HOME/sbxenv.yaml"; MOUNT_CONFIG="$1"; prepare_env_files',
                 'test', enabled],
                env={**os.environ, 'HOME': str(self.home), 'XDG_STATE_HOME': str(self.home / 'state')},
                capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            state = self.home / 'state/sbx-agent/environments/test'
            mounts = json.loads((state / 'runtime.yaml').read_text())['additionalWorkspaces']
            expected = [{'path': str(state.resolve() / 'git'), 'target': str(self.source), 'readOnly': True}]
            self.assertEqual(mounts, expected if enabled == 'true' else [])

    def test_symlink_destination_is_rejected(self):
        self.dest.parent.mkdir()
        self.dest.symlink_to(self.source)
        self.assertNotEqual(self.stage().returncode, 0)
        self.assertEqual((self.source / 'config').read_text(), 'original\n')


if __name__ == '__main__':
    unittest.main()
