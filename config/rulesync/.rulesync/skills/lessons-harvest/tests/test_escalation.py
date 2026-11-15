import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import escalation as E
import lessonlib as L


class VerificationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.patch = patch.object(L, "LESSONS_DIR", self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.path_patch = patch.object(E, "DIR", self.root / "escalation")
        self.path_patch.start()
        self.addCleanup(self.path_patch.stop)
        (self.root / "lessons/received/global").mkdir(parents=True)
        self.checklist = self.root / "escalation/global.md"
        (self.root / "fixtures").mkdir()
        self.lesson = self.root / "lessons/received/global/example.md"
        L.write(
            self.lesson,
            {"schema_version": 1, "title": "違反を防ぐ", "status": "active"},
            "## Patterns\n\n- 危険な値を渡す → 安全な値を渡す\n\n## Evidence\n",
        )
        (self.root / "fixtures/bad.txt").write_text("bad")
        (self.root / "fixtures/good.txt").write_text("good")
        self.config = {
            "cwd": str(self.root),
            "command": [
                sys.executable,
                "-c",
                'import pathlib,sys; bad=pathlib.Path(sys.argv[1]).read_text()=="bad"; print("CHECK001" if bad else "OK"); sys.exit(int(bad))',
                "{fixture}",
            ],
            "cases": [
                {
                    "pattern": "危険な値を渡す",
                    "bad": "fixtures/bad.txt",
                    "good": "fixtures/good.txt",
                    "diagnostic": "CHECK001",
                }
            ],
        }
        self.item = {
            "title": "違反を防ぐ",
            "path": "lessons/received/global/example.md",
            "checked": True,
            "tail": "",
            "lines": ["  - 仕組み: checker", "  - 検証: fixtures/check.json"],
        }
        E.save(self.checklist, {E.TODO: [self.item], E.DONE: []})

    def apply(self):
        (self.root / "fixtures/check.json").write_text(json.dumps(self.config))
        return E.apply()

    def test_detects_bad_accepts_good_and_rules(self):
        self.assertEqual(self.apply(), {"ruled": 1, "errors": []})
        self.assertEqual(L.read(self.lesson)[0]["status"], "ruled")
        self.assertEqual(len(E.load(self.checklist)[E.DONE]), 1)

    def test_undetected_bad_stays_active(self):
        self.config["command"] = [
            sys.executable,
            "-c",
            "import sys; print(sys.argv[1]); sys.exit(0)",
            "{fixture}",
        ]
        self.assertTrue(self.apply()["errors"])
        self.assertEqual(L.read(self.lesson)[0]["status"], "active")
        self.assertEqual(len(E.load(self.checklist)[E.TODO]), 1)

    def test_unrelated_failure_stays_active(self):
        self.config["command"] = [sys.executable, "-c", "import sys; sys.exit(1)", "{fixture}"]
        self.assertTrue(self.apply()["errors"])

    def test_good_failure_stays_active(self):
        (self.root / "fixtures/good.txt").write_text("bad")
        self.assertTrue(self.apply()["errors"])

    def test_missing_pattern_coverage_stays_active(self):
        self.config["cases"][0]["pattern"] = "別の違反"
        self.assertTrue(self.apply()["errors"])

    def test_path_escape_is_rejected(self):
        self.config["cases"][0]["bad"] = "../outside.txt"
        self.assertTrue(self.apply()["errors"])

    def test_split_checklist(self):
        target = self.root / "escalation/github.com/o/r.md"
        target.parent.mkdir(parents=True)
        self.checklist.rename(target)
        self.assertEqual(self.apply()["ruled"], 1)
        self.assertIn("## 済み", target.read_text())
        self.assertFalse((self.root / "escalation.md").exists())

    def test_timeout_stays_active(self):
        with patch.object(
            E.subprocess, "run", side_effect=subprocess.TimeoutExpired("checker", 30)
        ):
            self.assertTrue(self.apply()["errors"])
        self.assertEqual(L.read(self.lesson)[0]["status"], "active")

    def test_url_without_verification_stays_active(self):
        self.item["lines"] = ["  - 仕組み: https://github.com/o/r/pull/1"]
        E.save(self.checklist, {E.TODO: [self.item], E.DONE: []})
        self.assertTrue(self.apply()["errors"])
        self.assertEqual(L.read(self.lesson)[0]["status"], "active")

    def test_invalid_manifest_stays_active(self):
        self.config["cases"] = [42]
        self.assertTrue(self.apply()["errors"])

    def test_split_add_uses_scope(self):
        meta, body = L.read(self.lesson)
        meta["scope_key"] = "github.com/o/r"
        L.write(self.lesson, meta, body)
        self.checklist.unlink()
        E.add(
            [
                (
                    "lessons/received/github.com/o/r/example.md",
                    "違反を防ぐ",
                    {
                        "kind": "lint",
                        "detection": "CI",
                        "tool": "ruff:PLC2701",
                        "proposal": "違反を検出する",
                    },
                )
            ]
        )
        self.assertTrue((self.root / "escalation/github.com/o/r.md").is_file())
        self.assertFalse((self.root / "escalation.md").exists())

    def test_proposals(self):
        self.assertTrue(E.validate_proposal("free text"))
        self.assertFalse(
            E.validate_proposal(
                {
                    "kind": "lint",
                    "detection": "CI",
                    "tool": "ruff:PLC2701",
                    "proposal": "違反を検出する",
                }
            )
        )


if __name__ == "__main__":
    unittest.main()
