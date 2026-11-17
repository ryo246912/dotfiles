"""Basic Memory実行環境がある場合、文書の保存例を実際に再索引して検証する。"""

import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SKILL = Path(__file__).resolve().parents[1]
BINARY = os.environ.get("BEHAVIOR_BASIC_MEMORY_BIN") or shutil.which("basic-memory")
spec = importlib.util.spec_from_file_location(
    "behavior_reindex", SKILL / "scripts/list_lessons.py"
)
lessons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lessons)


@unittest.skipUnless(
    BINARY, "Basic Memory未導入。BEHAVIOR_BASIC_MEMORY_BINで実行ファイルを指定できる"
)
class ReindexTest(unittest.TestCase):
    def test_documented_note_remains_readable_after_reindex(self):
        example = (
            (SKILL / "references/lesson-format.md")
            .read_text()
            .split("```markdown\n", 1)[1]
            .split("\n```", 1)[0]
        )
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            clone = base / "clone"
            root = clone / "behavor"
            note = root / "example-org/example-app/preview-login-per-origin.md"
            note.parent.mkdir(parents=True)
            note.write_text(example)
            expected = note.read_bytes()
            env = dict(
                os.environ,
                BASIC_MEMORY_CONFIG_DIR=str(base / "config"),
                HF_HOME=str(base / "hf-cache"),
                XDG_CACHE_HOME=str(base / "cache"),
                BASIC_MEMORY_HOME=str(base / "default"),
                BASIC_MEMORY_SEMANTIC_SEARCH_ENABLED="false",
                BASIC_MEMORY_AUTO_UPDATE="false",
            )
            for args in (
                ["project", "add", "behavior-test", str(clone), "--no-wait"],
                ["reindex", "--search", "-p", "behavior-test"],
            ):
                result = subprocess.run(
                    [BINARY, *args],
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=180,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(
                note.read_bytes(), expected, "再索引によって保存形式が変更された"
            )
            result = lessons.lesson_index(
                None, "example-org/example-app", lessons_dir=root
            )
            self.assertEqual(result["warnings"], [])
            self.assertEqual(len(result["lessons"]), 1)


if __name__ == "__main__":
    unittest.main()
