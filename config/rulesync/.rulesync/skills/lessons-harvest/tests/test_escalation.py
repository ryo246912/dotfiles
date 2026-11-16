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

    def assert_rejected(self):
        self.assertTrue(self.apply()["errors"])
        self.assertEqual(L.read(self.lesson)[0]["status"], "active")
        items = E.load(self.checklist)
        self.assertEqual([it["path"] for it in items[E.TODO]], [self.item["path"]])
        self.assertEqual(items[E.DONE], [])

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
        self.assert_rejected()
        self.assertEqual(L.read(self.lesson)[0]["status"], "active")
        self.assertEqual(len(E.load(self.checklist)[E.TODO]), 1)

    def test_unrelated_failure_stays_active(self):
        self.config["command"] = [sys.executable, "-c", "import sys; sys.exit(1)", "{fixture}"]
        self.assert_rejected()

    def test_good_failure_stays_active(self):
        (self.root / "fixtures/good.txt").write_text("bad")
        self.assert_rejected()

    def test_missing_pattern_coverage_stays_active(self):
        self.config["cases"][0]["pattern"] = "別の違反"
        self.assert_rejected()

    def test_path_escape_is_rejected(self):
        self.config["cases"][0]["bad"] = "../outside.txt"
        self.assert_rejected()

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
            self.assert_rejected()
        self.assertEqual(L.read(self.lesson)[0]["status"], "active")

    def test_url_without_verification_stays_active(self):
        self.item["lines"] = ["  - 仕組み: https://github.com/o/r/pull/1"]
        E.save(self.checklist, {E.TODO: [self.item], E.DONE: []})
        self.assert_rejected()
        self.assertEqual(L.read(self.lesson)[0]["status"], "active")

    def test_invalid_manifest_stays_active(self):
        self.config["cases"] = [42]
        self.assert_rejected()

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
        target = self.root / "escalation/github.com/o/r.md"
        self.assertEqual(
            [it["path"] for it in E.load(target)[E.TODO]],
            ["lessons/received/github.com/o/r/example.md"],
        )
        self.assertFalse((self.root / "escalation.md").exists())

    def test_unreadable_pattern_prevents_ruling(self):
        for pattern in ("矢印のない違反例", " → 修正する", "違反する → "):
            with self.subTest(pattern=pattern):
                meta, body = L.read(self.lesson)
                body = L.set_section(
                    body, "Patterns", "- 危険な値を渡す → 安全な値を渡す\n- " + pattern
                )
                L.write(self.lesson, meta, body)
                self.assert_rejected()

    def test_proposal_line_separators_are_normalized(self):
        self.checklist.unlink()
        proposal = {
            "kind": "lint",
            "detection": "CI",
            "tool": "ruff:PLC2701",
            "proposal": "違反を\r検出する\u2028ルールを\x85入れる",
        }
        E.add([(self.item["path"], "違反を防ぐ", proposal)])
        items = E.load(self.checklist)[E.TODO]
        self.assertEqual(len(items), 1)
        self.assertEqual(E.field(items[0], "案"), "違反を 検出する ルールを 入れる")
        self.assertEqual(E.field(items[0], "検証"), "")

    def test_incomplete_proposal_can_be_repaired_without_losing_user_fields(self):
        original = {
            **self.item,
            "lines": ["  - 案: 旧い案", *self.item["lines"], "  - メモ: 検証を準備中"],
        }
        E.save(self.checklist, {E.TODO: [original], E.DONE: []})
        proposal = {
            "kind": "lint",
            "detection": "CI",
            "tool": "ruff:PLC2701",
            "proposal": "違反を検出する",
        }
        self.assertEqual(
            E.add([(self.item["path"], self.item["title"], proposal)]), [self.item["title"]]
        )
        items = E.load(self.checklist)
        self.assertEqual(len(items[E.TODO]), 1)
        actual = items[E.TODO][0]
        self.assertEqual(
            {key: actual[key] for key in ("checked", "title", "path", "tail")},
            {key: original[key] for key in ("checked", "title", "path", "tail")},
        )
        self.assertEqual({key: E.field(actual, label) for key, label in E.FIELDS.items()}, proposal)
        for label in ("仕組み", "検証", "メモ"):
            self.assertEqual(E.field(actual, label), E.field(original, label))
        self.assertEqual(
            E.add(
                [(self.item["path"], self.item["title"], {**proposal, "proposal": "別の案にする"})]
            ),
            [],
        )
        self.assertEqual(E.field(E.load(self.checklist)[E.TODO][0], "案"), proposal["proposal"])

    def test_completed_entry_is_not_repaired(self):
        E.save(self.checklist, {E.TODO: [], E.DONE: [self.item]})
        proposal = {
            "kind": "lint",
            "detection": "CI",
            "tool": "ruff:PLC2701",
            "proposal": "違反を検出する",
        }
        self.assertEqual(E.add([(self.item["path"], self.item["title"], proposal)]), [])
        self.assertEqual(E.load(self.checklist), {E.TODO: [], E.DONE: [self.item]})

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
