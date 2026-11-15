"""同期が不正な知見をcommitする前に止まることを検証する。"""

import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path


class SyncFrontmatterTest(unittest.TestCase):
    def test_staged_behavior_notes_and_readme(self):
        repo = next(
            parent
            for parent in Path(__file__).resolve().parents
            if (parent / "mise.toml").exists()
        )
        task = tomllib.loads((repo / "config/mise/tasks/lessons.toml").read_text())[
            "lessons:sync"
        ]["run"]
        check = task.split("python3 - <<'PY'\n", 1)[1].split("\nPY\n", 1)[0]
        cases = [
            ("behavor/README.md", "# Readme\n", True),
            (
                "behavor/owner/repo/valid.md",
                '---\npermalink: "agent-lessons/behavor/owner/repo/valid"\n---\nbody',
                True,
            ),
            ("behavor/owner/repo/missing.md", "# Missing frontmatter", False),
            (
                "behavor/owner/repo/conflict.md",
                "<<<<<<< HEAD\n---\ntitle: x\n---\n",
                False,
            ),
            ("behavor/owner/repo/unterminated.md", "---\ntitle: x\nbody", False),
            (
                "behavor/owner/repo/marker.md",
                "---\n<<<<<<< HEAD\ntitle: x\n---\n",
                False,
            ),
        ]
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            for name, content, allowed in cases:
                with self.subTest(name=name):
                    subprocess.run(
                        ["git", "read-tree", "--empty"], cwd=root, check=True
                    )
                    path = root / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(content)
                    subprocess.run(["git", "add", name], cwd=root, check=True)
                    result = subprocess.run(
                        [sys.executable, "-c", check],
                        cwd=root,
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(result.returncode == 0, allowed, result.stderr)


if __name__ == "__main__":
    unittest.main()
