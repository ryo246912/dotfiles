"""共通知見のパスをbriefへ引き継ぐ際の検証。"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from render_brief import check_manual_test


class LessonCaptureTest(unittest.TestCase):
    def errors(self, path):
        return check_manual_test(
            {
                "manual_test": {
                    "lesson_capture": {
                        "status": "SAVED",
                        "files": [path],
                        "note": "保存を読み直して確認",
                    }
                }
            }
        )

    def test_shared_and_legacy_paths(self):
        for prefix in ("behavor", "lessons"):
            with self.subTest(prefix=prefix):
                self.assertEqual(self.errors(f"{prefix}/owner/repo/login.md"), [])

    def test_external_paths_are_rejected(self):
        for path in (
            "/behavor/owner/repo/login.md",
            "behavor/../repo/login.md",
            "config/owner/repo/config.md",
            "behavor/owner/repo/login.json",
            "behavor\\owner\\repo\\login.md",
        ):
            with self.subTest(path=path):
                self.assertTrue(self.errors(path))


if __name__ == "__main__":
    unittest.main()
