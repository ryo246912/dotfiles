"""Regression coverage for harvest proposal validation and missing-proposal triage."""

import datetime as dt
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import apply_plan
import escalation
import lessonlib as L


class ProposalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.patch = patch.object(L, "LESSONS_DIR", self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.dir_patch = patch.object(escalation, "DIR", self.root / "escalation")
        self.dir_patch.start()
        self.addCleanup(self.dir_patch.stop)
        self.path = "lessons/received/global/private-import.md"
        L.write(
            self.root / self.path,
            {
                "title": "非公開の名前を参照しない",
                "type": "lesson",
                "status": "active",
                "source": "received",
                "scope_key": "global",
                "category": "imports",
                "last_seen": str(dt.date.today()),
                "since_active": 2,
            },
            "\n## Rule\n非公開の名前を参照しない。\n\n## Patterns\n- 非公開の名前を参照する → 公開名を使う\n\n## Check\n非公開名を参照する箇所。\n\n## Evidence\n",
        )
        self.proposal = {
            "kind": "lint",
            "detection": "CI",
            "tool": "ruff:PLC2701",
            "proposal": "非公開名を参照するルールを有効にする",
        }

    def test_structured_proposal_passes_plan_validation(self):
        self.assertEqual(apply_plan.check_plan({"escalate": {self.path: self.proposal}}, {}), [])

    def test_free_text_and_incomplete_proposals_are_rejected(self):
        for value in (
            "検出する",
            {},
            {**self.proposal, "kind": "unknown"},
            {**self.proposal, "detection": "unknown"},
            {**self.proposal, "tool": ""},
            {**self.proposal, "proposal": ""},
        ):
            with self.subTest(value=value):
                self.assertTrue(apply_plan.check_plan({"escalate": {self.path: value}}, {}))

    def test_empty_escalation_list_is_rejected(self):
        self.assertTrue(apply_plan.check_plan({"escalate": []}, {}))

    def test_english_proposal_is_rejected_without_checking_identifiers(self):
        proposal = {**self.proposal, "proposal": "Enable private imports checking"}
        self.assertTrue(
            any(
                "日本語" in error
                for error in apply_plan.check_plan({"escalate": {self.path: proposal}}, {})
            )
        )

    def run_empty_plan(self):
        work = self.root / "work"
        (work / "observations").mkdir(parents=True)
        (work / "observations/sessions.done").touch()
        (work / "plan.json").write_text("{}")
        with (
            patch.object(sys, "argv", ["apply_plan.py", "--work", str(work)]),
            patch.object(escalation, "add") as add,
        ):
            add.return_value = []
            self.assertEqual(apply_plan.main(), 0)
        add.assert_called_once_with([])
        self.assertEqual(L.read(self.root / self.path)[0]["status"], "active")
        return (work / "pr-body.md").read_text()

    def test_repeated_lesson_without_proposal_goes_to_review(self):
        self.assertIn("構造化した案が無い", self.run_empty_plan())

    def test_existing_proposal_is_not_requested_again(self):
        escalation.add([(self.path, "非公開の名前を参照しない", self.proposal)])
        self.assertNotIn("構造化した案が無い", self.run_empty_plan())

    def test_incomplete_existing_proposal_still_goes_to_review(self):
        target = escalation.path_for("global")
        escalation.save(
            target,
            {
                escalation.TODO: [
                    {
                        "checked": False,
                        "title": "非公開の名前を参照しない",
                        "path": self.path,
                        "tail": "",
                        "lines": ["  - 案:"],
                    }
                ],
                escalation.DONE: [],
            },
        )
        self.assertIn("構造化した案が無い", self.run_empty_plan())

    def test_widened_lesson_cannot_have_proposal(self):
        meta, body = L.read(self.root / self.path)
        first = "lessons/received/github.com/o/one/private-import.md"
        second = "lessons/received/github.com/o/two/private-import.md"
        L.write(self.root / first, {**meta, "scope_key": "github.com/o/one"}, body)
        L.write(self.root / second, {**meta, "scope_key": "github.com/o/two"}, body)
        plan = {
            "widen": [
                {
                    "lessons": [first, second],
                    "scope_key": "github.com/o",
                    "key": "private-import",
                    "title": "非公開名を参照しない",
                    "rule": "公開名を使う",
                    "why": "仕様を守るため",
                    "check": "非公開名を探す",
                }
            ],
            "escalate": {first: self.proposal},
        }
        self.assertEqual(apply_plan.check_plan({"widen": plan["widen"]}, {}), [])
        self.assertTrue(
            any("まとめる教訓には" in error for error in apply_plan.check_plan(plan, {}))
        )


if __name__ == "__main__":
    unittest.main()
