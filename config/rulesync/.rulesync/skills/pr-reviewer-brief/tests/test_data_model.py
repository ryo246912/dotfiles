"""ER 図の省略条件と API 呼び出し引き継ぎの回帰テスト。"""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from render_brief import build, check_data_model


class DataModelTest(unittest.TestCase):
    def exemption(self):
        return {
            'note': '固定文字列のみを表示する。入口から描画まで追跡済み。',
            'trace': [{'entry': 'web/title.ts:1', 'steps': ['web/title.ts:1-8'], 'result': '文字列定数を描画するだけ'}],
            'evidence': [{'path': 'web/title.ts', 'lines': '1-8'}],
        }

    def brief(self, model):
        return {'title': '確認', 'tldr': ['概要'], 'background': {'data_model': model}}

    def test_exemption_requires_trace_and_evidence(self):
        model = self.exemption()
        self.assertEqual(check_data_model(self.brief(model), []), [])
        for key in ('trace', 'evidence', 'note'):
            with self.subTest(key=key):
                incomplete = {k: v for k, v in model.items() if k != key}
                self.assertTrue(check_data_model(self.brief(incomplete), []))

    def test_database_mentions_cannot_exempt(self):
        for note in ('既存の API で downloaded_addresses に入る', 'テーブル変更なし', 'DB変更なし', 'downloaded_addresses'):
            with self.subTest(note=note):
                self.assertTrue(check_data_model(self.brief({**self.exemption(), 'note': note}), []))

    def test_api_context_requires_er_diagram(self):
        for section, value in [('interfaces', [{'kind': 'API', 'change': '既存処理を呼ぶ'}]), ('changes', {'before_after': [{'after': 'mutation を呼ぶ'}]})]:
            with self.subTest(section=section):
                brief = self.brief(self.exemption())
                brief[section] = value
                self.assertTrue(check_data_model(brief, []))
        self.assertTrue(check_data_model({'background': {'pages': [{'id': 'list'}]}}, []))

    def test_mermaid_required_and_accepted(self):
        for tables in ('<svg>図</svg>', '```mermaid\nerDiagram\n```'):
            self.assertTrue(check_data_model(self.brief({'tables': tables}), []))
        self.assertEqual(check_data_model(self.brief({'tables': 'erDiagram\n ITEMS { int id PK }'}), [{'call': 'fetch'}]), [])

    def test_build_reads_handoff_and_displays_trace(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            (work / 'brief.json').write_text(json.dumps(self.brief(self.exemption())))
            page, errors = build(work)
            self.assertFalse(errors)
            self.assertIn('データの追跡結果', page)
            self.assertIn('web/title.ts', page)
            (work / 'api_calls.json').write_text('[{"call": "client.addresses.create"}]')
            page, errors = build(work)
            self.assertEqual(page, '')
            self.assertTrue(any('ER 図が必要' in error for error in errors))
            (work / 'api_calls.json').write_text('{}')
            self.assertTrue(build(work)[1])


if __name__ == '__main__':
    unittest.main()
