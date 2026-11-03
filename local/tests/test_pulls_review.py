"""Offline regression tests: python3 -m unittest discover -s local/tests."""

import contextlib
import copy
import importlib.machinery
import importlib.util
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "pulls-review"
LOADER = importlib.machinery.SourceFileLoader("pulls_review", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
review = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(review)


class PullsReviewTests(unittest.TestCase):
    def setUp(self):
        self.base = "a" * 40
        self.head = "c" * 40
        self.stack = {
            "number": 9,
            "base": {"ref": "release/test"},
            "pull_requests": [
                {"number": number, "head": {"sha": self.head}}
                for number in (123, 124, 125)
            ],
        }
        self.paths = []

    def api(self, path):
        self.paths.append(path)
        if "/pulls/" in path:
            number = int(path.rsplit("/", 1)[1])
            return {"stack": None if number == 99 else {"number": 9, "size": 3}}
        if "/stacks/" in path:
            return copy.deepcopy(self.stack)
        if "/commits/" in path:
            return {"sha": self.base}
        raise AssertionError(path)

    def gh(self, *args):
        if args[:2] == ("repo", "view"):
            return "owner/repo"
        if args[:2] == ("pr", "view"):
            return "124"
        raise AssertionError(args)

    def run_cli(self, *args, status=0):
        with (
            patch.object(sys, "argv", ["pulls-review", *args]),
            patch.object(review, "api", self.api),
            patch.object(review, "gh", self.gh),
            patch.object(review.shutil, "which", return_value="/bin/mock"),
            patch.object(review.subprocess, "run") as command,
            contextlib.redirect_stdout(io.StringIO()),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            try:
                review.main()
                result = 0
            except SystemExit as error:
                result = error.code
            self.assertEqual(result, status)
            return command

    def test_every_stack_layer_opens_full_comparison(self):
        for number in (123, 124, 125):
            with self.subTest(number=number):
                command = self.run_cli(str(number))
                self.assertEqual(command.call_args.args[0], [
                    "pulls.review",
                    f"https://github.com/owner/repo/compare/{self.base}...{self.head}",
                ])
                self.assertIn("repos/owner/repo/commits/release%2Ftest", self.paths)

    def test_no_argument_uses_current_branch_pr(self):
        command = self.run_cli()
        self.assertIn("repos/owner/repo/pulls/124", self.paths)
        self.assertTrue(command.called)

    def test_standalone_pr_stays_a_pr(self):
        command = self.run_cli("99")
        self.assertEqual(command.call_args.args[0], [
            "pulls.review", "https://github.com/owner/repo/pull/99",
        ])
        self.assertEqual(self.paths, ["repos/owner/repo/pulls/99"])

    def test_explicit_url_and_shorthand(self):
        for value in ("owner/repo#124", "https://github.com/owner/repo/pull/124"):
            with self.subTest(value=value):
                self.assertTrue(self.run_cli(value).called)

    def test_dry_run_does_not_launch(self):
        self.run_cli("124", "--dry-run").assert_not_called()

    def test_diff_uses_combined_compare_endpoint(self):
        command = self.run_cli("124", "--diff")
        self.assertEqual(command.call_args.args[0], [
            "gh", "api", "--hostname", "github.com", "-H",
            "Accept: application/vnd.github.diff",
            f"repos/owner/repo/compare/{self.base}...{self.head}",
        ])

    def test_single_pr_diff(self):
        command = self.run_cli("99", "--diff")
        self.assertEqual(command.call_args.args[0][-1], "repos/owner/repo/pulls/99")

    def test_server_options(self):
        command = self.run_cli("124", "--no-open", "--port", "3000")
        self.assertEqual(command.call_args.args[0][-3:], ["--no-open", "--port", "3000"])

    def test_api_posting_options_are_rejected(self):
        self.run_cli("99", "--post", status=2).assert_not_called()
        self.run_cli("99", "--provider", "anthropic", status=2).assert_not_called()

    def test_conflicting_modes_are_rejected(self):
        self.run_cli("124", "--diff", "--dry-run", status=2).assert_not_called()

    def test_stack_api_errors_do_not_fall_back_to_single_pr(self):
        def failing(path):
            if "/stacks/" in path:
                raise ValueError("stack lookup failed")
            return self.api(path)
        with patch.object(review, "api", failing):
            with self.assertRaisesRegex(ValueError, "stack lookup failed"):
                review.review_target("owner/repo", 124)

    def test_stack_changes_are_detected(self):
        self.stack["pull_requests"].pop()
        with patch.object(review, "api", self.api):
            with self.assertRaisesRegex(ValueError, "stack changed"):
                review.review_target("owner/repo", 124)

    def test_duplicate_members_are_rejected(self):
        self.stack["pull_requests"][0]["number"] = 124
        with patch.object(review, "api", self.api):
            with self.assertRaisesRegex(ValueError, "inconsistent stack"):
                review.review_target("owner/repo", 124)

    def test_base_sha_avoids_branch_resolution(self):
        self.stack["base"]["sha"] = self.base
        with patch.object(review, "api", self.api):
            review.review_target("owner/repo", 124)
        self.assertFalse(any("/commits/" in path for path in self.paths))

    def test_missing_cli_reports_install_command(self):
        with (
            patch.object(sys, "argv", ["pulls-review", "99"]),
            patch.object(review, "api", self.api),
            patch.object(review, "gh", self.gh),
            patch.object(review.shutil, "which", return_value=None),
            contextlib.redirect_stderr(io.StringIO()) as error,
        ):
            with self.assertRaises(SystemExit):
                review.main()
        self.assertIn("mise install npm:pulls.review", error.getvalue())


if __name__ == "__main__":
    unittest.main()
