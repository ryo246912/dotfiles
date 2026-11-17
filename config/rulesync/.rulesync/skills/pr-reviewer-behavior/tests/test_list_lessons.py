import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/list_lessons.py"
spec = importlib.util.spec_from_file_location("behavior_lessons", SCRIPT)
lessons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lessons)


class LessonIndexTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.clone = self.home / ".local/share/agent-lessons"
        self.clone.mkdir(parents=True)
        self.root = self.clone / "behavor"

    def write(self, name="login", **overrides):
        path = self.root / "Owner/Repo" / (name + ".md")
        path.parent.mkdir(parents=True, exist_ok=True)
        values = dict(
            schema_version=1,
            permalink=f"agent-lessons/behavor/owner/repo/{name}",
            title="Login",
            summary="Preview login",
            repository="owner/repo",
            environment="local",
            status="active",
            created_at="2026-11-15",
            updated_at="2026-11-15",
            tags=["auth"],
            evidence=[],
        )
        values.update(overrides)
        path.write_text(
            "---\n"
            + "".join(f"{k}: {json.dumps(v)}\n" for k, v in values.items())
            + "---\nBODY MUST NOT BE LISTED\n"
        )
        return path

    def index(self, **kwargs):
        with patch.object(Path, "home", return_value=self.home):
            return lessons.lesson_index(None, "owner/repo", **kwargs)

    def test_default_shared_root_and_filters(self):
        self.write()
        self.write("shared", environment="all")
        self.write("staging", environment="staging")
        self.write("retired", status="retired")
        result = self.index(environment="local", query="AUTH")
        self.assertEqual(
            [r["path"] for r in result["lessons"]],
            ["behavor/Owner/Repo/login.md", "behavor/Owner/Repo/shared.md"],
        )
        self.assertNotIn("BODY MUST NOT BE LISTED", json.dumps(result))
        self.assertEqual(result["warnings"], [])

    def test_missing_behavor_is_empty_but_missing_clone_is_error(self):
        self.assertEqual(self.index()["lessons"], [])
        self.clone.rmdir()
        with self.assertRaises(FileNotFoundError):
            self.index()

    def test_explicit_root_and_legacy_migration(self):
        self.write()
        self.assertEqual(
            len(
                lessons.lesson_index(None, "owner/repo", lessons_dir=self.root)[
                    "lessons"
                ]
            ),
            1,
        )
        config = self.home / "config.md"
        config.touch()
        self.root.rename(self.home / "lessons")
        result = lessons.lesson_index(config, "owner/repo")
        self.assertEqual(result["lessons"][0]["path"], "lessons/Owner/Repo/login.md")
        with self.assertRaises(ValueError):
            lessons.lesson_index(config, "owner/repo", lessons_dir=self.root)

    def test_shared_clone_symlink_is_allowed(self):
        self.write()
        actual = self.home / "actual-clone"
        self.clone.rename(actual)
        self.clone.symlink_to(actual, target_is_directory=True)
        self.assertEqual(len(self.index()["lessons"]), 1)

    def test_root_and_owner_symlinks_are_rejected(self):
        elsewhere = self.home / "elsewhere"
        elsewhere.mkdir()
        self.root.symlink_to(elsewhere, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.index()
        self.root.unlink()
        self.root.mkdir()
        (self.root / "owner").symlink_to(elsewhere, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.index()

    def test_file_symlink_and_markdown_directory_are_not_read(self):
        path = self.write()
        (path.parent / "alias.md").symlink_to(path)
        (path.parent / "directory.md").mkdir()
        result = self.index()
        self.assertEqual(len(result["lessons"]), 1)
        self.assertEqual(len(result["warnings"]), 2)

    def test_unknown_schema_stops_index_and_malformed_warns(self):
        path = self.write(schema_version=2, permalink=None)
        with self.assertRaises(lessons.UnsupportedSchemaVersionError):
            self.index()
        path.write_text("---\nschema_version: nope\n---\n")
        self.assertEqual(len(self.index()["warnings"]), 1)

    def test_missing_permalink_warns_only_for_shared_notes(self):
        path = self.write()
        text = path.read_text()
        path.write_text(
            "\n".join(
                line for line in text.split("\n") if not line.startswith("permalink:")
            )
        )
        self.assertEqual(len(self.index()["warnings"]), 1)
        config = self.home / "config.md"
        config.touch()
        self.root.rename(self.home / "lessons")
        self.assertEqual(len(lessons.lesson_index(config, "owner/repo")["lessons"]), 1)

    def test_block_yaml_is_reported_instead_of_silently_dropped(self):
        path = self.write()
        path.write_text(path.read_text().replace('tags: ["auth"]', "tags:\n- auth"))
        self.assertEqual(len(self.index()["warnings"]), 1)

    def test_self_referential_root_symlink_is_rejected(self):
        self.root.symlink_to("behavor")
        with self.assertRaises(ValueError):
            self.index()

    def test_repository_boundary(self):
        self.write(repository="other/repo")
        self.assertEqual(len(self.index()["warnings"]), 1)
        with self.assertRaises(ValueError):
            lessons.lesson_index(None, "../repo", lessons_dir=self.root)


if __name__ == "__main__":
    unittest.main()
