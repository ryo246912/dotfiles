import importlib.util
import json
import os
import subprocess
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("contracts", ROOT / "scripts/check-config-contracts.py")
contracts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contracts)


class ContractsTest(unittest.TestCase):
    def test_checked_in_configuration(self):
        self.assertEqual(contracts.check(ROOT), [])

    def test_old_schema_and_divergent_global_pin(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("mise.toml", "config/mise/config.toml", "config/devcontainer/lint/oxlint.json"):
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, target)
            schema = root / "config/devcontainer/lint/oxlint.json"
            data = json.loads(schema.read_text())
            data["$schema"] = data["$schema"].replace("oxlint_v", "oxlint_v0.0.0-")
            schema.write_text(json.dumps(data))
            self.assertTrue(any("oxlint-schema:" in e for e in contracts.check_versions(root)))
            shutil.copyfile(ROOT / "config/devcontainer/lint/oxlint.json", schema)
            pin = root / "config/mise/config.toml"
            version = contracts.load_toml(pin)["tools"]["npm:oxlint"]
            pin.write_text(pin.read_text().replace(f'"{version}"', '"0.0.0"'))
            self.assertTrue(any("oxlint-version:" in e for e in contracts.check_versions(root)))

    def test_glob_must_not_launch_wrapper_internals(self):
        tasks = {
            "fix:all": {"depends": ["fix:*"]},
            "fix:action": {"run": [{"task": "fix:pinact"}]},
            "fix:pinact": {},
        }
        errors = contracts.check_tasks(tasks)
        self.assertTrue(any("task-duplicate:" in e for e in errors))
        self.assertTrue(any("task-cycle:" in e for e in errors))
        tasks["fix:all"]["depends"] = ["fix:action"]
        self.assertEqual(contracts.check_tasks(tasks), [])

    def test_shared_depends_is_deduplicated(self):
        tasks = {
            "fix:all": {"depends": ["fix:yaml", "fix:dockerfile-pin"]},
            "fix:yaml": {"depends": ["fix:dockerfile-pin"]},
            "fix:dockerfile-pin": {},
        }
        self.assertEqual(contracts.check_tasks(tasks), [])

    def test_run_and_depends_cannot_schedule_same_task(self):
        tasks = {"fix:all": {"depends": ["fix:one"], "run": [{"task": "fix:one"}]}, "fix:one": {}}
        self.assertTrue(any("task-duplicate:" in e for e in contracts.check_tasks(tasks)))

    def test_checkout_only_registers_hooks(self):
        result = subprocess.run(["lefthook", "dump", "--format", "json"], cwd=ROOT,
                                text=True, capture_output=True, check=True)
        config = json.loads(result.stdout)
        checkout = config["post-checkout"]
        self.assertFalse(checkout.get("commands"))
        self.assertFalse(checkout.get("scripts"))
        self.assertEqual([job["name"] for job in checkout["jobs"]], ["lefthook-install"])
        merge_names = [job["name"] for job in config["post-merge"]["jobs"]]
        self.assertIn("dotfiles-apply", merge_names)
        self.assertIn("ensure-mise-version", merge_names)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stub = root / "mise"
            stub.write_text('#!/bin/sh\n[ "$1" = exec ] && [ "$2" = -- ] || exit 9\nshift 2\nexec "$@"\n')
            stub.chmod(0o755)
            lefthook = root / "lefthook"
            lefthook.write_text('#!/bin/sh\n[ "$*" = install ] || exit 9\ntouch registered\n')
            lefthook.chmod(0o755)
            env = dict(os.environ, PATH=f"{root}:/usr/bin:/bin", LEFTHOOK_CONFIG="lefthook.yml")
            command = ["sh", "-eu", "-c", checkout["jobs"][0]["run"]]
            subprocess.run(command, cwd=root, env=env, check=True)
            self.assertFalse((root / "registered").exists())
            (root / "lefthook.yml").touch()
            subprocess.run(command, cwd=root, env=env, check=True)
            self.assertTrue((root / "registered").exists())

    def test_missing_dependency(self):
        self.assertTrue(contracts.check_tasks({"fix:all": {"depends": ["missing:*"]}}))


if __name__ == "__main__":
    unittest.main()
