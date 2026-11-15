"""escalation の scope_key 別ファイルへの追加・移動の回帰テスト。"""

import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import escalation as E

X = "lessons/received/github.com/acme/x/n.md"
Y = "lessons/received/github.com/acme/y/n.md"
Z = "lessons/received/github.com/acme/z/n.md"


class EscalationTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        patcher = mock.patch.object(E, "DIR", Path(tmp.name))
        patcher.start()
        self.addCleanup(patcher.stop)

    def todo(self, scope):
        return E.load(E.path_for(scope))[E.TODO]

    def test_add_groups_by_scope(self):
        """add は scope_key ごとのファイルに入れ、載っている教訓を足さない。"""
        E.add([(X, "t", "p"), (Y, "u", "p")])
        self.assertEqual(E.add([(X, "t", "p")]), [])
        self.assertEqual([i["path"] for i in self.todo("github.com/acme/x")], [X])
        self.assertEqual([i["path"] for i in self.todo("github.com/acme/y")], [Y])

    def test_relink_moves_keeping_mark_and_mechanism(self):
        """relink は印と仕組みを保ったまま移動先のファイルへ移す。"""
        E.add([(X, "t", "p")])
        f = E.path_for("github.com/acme/x")
        f.write_text(f.read_text().replace("- [ ]", "- [x]").replace("仕組み:", "仕組み: hook"))
        E.relink({X: Y}, {})
        moved = self.todo("github.com/acme/y")
        self.assertEqual(self.todo("github.com/acme/x"), [])
        self.assertEqual([i["path"] for i in moved], [Y])
        self.assertTrue(moved[0]["checked"])
        self.assertEqual(E.mechanism(moved[0]), "hook")

    def test_relink_chained_moves(self):
        """relink は連鎖した移動（x→y、y→z）でも項目を失わない。"""
        E.add([(X, "a", "p"), (Y, "b", "p")])
        E.relink({X: Y, Y: Z}, {})
        self.assertEqual([i["path"] for i in self.todo("github.com/acme/z")], [Z])

    def test_relink_retry_after_partial_save(self):
        """relink は途中で保存に失敗しても、再実行で移動先に 1 件だけ残る。"""
        E.add([(X, "t", "p")])
        real, calls = E.save, []

        def flaky(path, items):
            calls.append(path)
            if len(calls) == 2:
                raise OSError("disk")
            real(path, items)

        with mock.patch.object(E, "save", flaky):
            try:
                E.relink({X: Y}, {})
            except OSError:
                pass
            else:
                self.fail("保存の失敗が伝わらなかった")
        paths = [
            i["path"] for s in ("github.com/acme/x", "github.com/acme/y") for i in self.todo(s)
        ]
        self.assertTrue(paths)
        E.relink({X: Y}, {})
        self.assertEqual([i["path"] for i in self.todo("github.com/acme/y")], [Y])


if __name__ == "__main__":
    unittest.main()
