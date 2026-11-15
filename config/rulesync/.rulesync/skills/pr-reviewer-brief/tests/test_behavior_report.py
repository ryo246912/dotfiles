"""behaviorの観測結果と各ステップの画像をbriefへ統合する回帰テスト。"""
import base64
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from render_brief import build, check_manual_test, manual_test_section


PNG = base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='
)


class BehaviorReportTest(unittest.TestCase):
    def report(self):
        return {
            'head_sha': 'abc123',
            'manual_test': {
                'execution': {'status': 'PASS', 'head_sha': 'abc123', 'account': '管理者 / admin'},
                'preparation': [{
                    'id': 'prep-1', 'title': '準備画面', 'actions': ['専用データを作る'],
                    'expected': ['下書きができる'], 'status': 'PASS', 'actual': '下書きの存在を確認',
                }],
                'data': [{'purpose': '確認用', 'record': 'id=7 / テスト', 'state': '下書き',
                          'url': 'http://localhost:3000/items/7', 'source': '作成'}],
                'steps': [{
                    'id': 'step-1', 'title': '確認画面', 'actions': ['詳細を開く'],
                    'expected': ['下書きが見える'], 'status': 'PASS', 'actual': '詳細で状態を確認',
                }],
                'cleanup': ['手動確認用にid=7を残す'],
            },
        }

    def test_preparation_results_and_step_images_are_in_one_report(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            shots = work / 'screenshots'
            shots.mkdir()
            manifest = []
            for step in ('prep-1', 'step-1'):
                (shots / f'{step}.png').write_bytes(PNG)
                manifest.append({'id': step, 'ok': True, 'path': f'{step}.png'})
            (shots / 'manifest.json').write_text(json.dumps(manifest))
            brief = self.report()
            brief.update({'title': '動作確認', 'tldr': ['概要'], 'background': {'data_model': {
                'note': '固定文字列のみ。描画まで追跡済み。',
                'trace': [{'entry': 'web/title.ts:1', 'steps': ['web/title.ts:1'], 'result': '固定文字列'}],
                'evidence': [{'path': 'web/title.ts', 'lines': '1'}],
            }}})
            (work / 'brief.json').write_text(json.dumps(brief))
            page, errors = build(work)
            self.assertFalse(errors)
            self.assertIn('動作確認方法', page)
            self.assertIn('下書きの存在を確認', page)
            self.assertIn('詳細で状態を確認', page)
            self.assertIn('id=7 / テスト', page)
            self.assertIn('手動確認用にid=7を残す', page)
            self.assertEqual(page.count('data:image/png;base64,'), 2)
            prep = page.index('id="prep-1"')
            verify = page.index('id="step-1"')
            self.assertLess(prep, page.index('data:image/png;base64,'))
            self.assertLess(page.index('data:image/png;base64,'), verify)
            self.assertLess(verify, page.rindex('data:image/png;base64,'))

    def test_blocked_and_not_run_are_visible_without_fabricated_images(self):
        with tempfile.TemporaryDirectory() as directory:
            brief = {'manual_test': {
                'execution': {'status': 'BLOCKED', 'note': 'ログイン待ち'},
                'preparation': [{'id': 'prep-1', 'title': 'ログイン', 'status': 'BLOCKED',
                                 'image_note': '認証画面は撮影しない'}],
                'steps': [{'id': 'step-1', 'title': '保存'}],
            }}
            self.assertFalse(check_manual_test(brief))
            page = manual_test_section(brief, Path(directory))
            for text in ('BLOCKED', 'NOT RUN', 'ログイン待ち', '認証画面は撮影しない'):
                self.assertIn(text, page)
            self.assertNotIn('<img', page)

    def test_claimed_execution_requires_actual_result_and_matching_sha(self):
        brief = self.report()
        brief['manual_test']['steps'][0]['actual'] = ''
        self.assertTrue(any('actual' in e for e in check_manual_test(brief)))
        brief = self.report()
        brief['manual_test']['execution']['head_sha'] = 'older-sha'
        self.assertTrue(any('SHA' in e for e in check_manual_test(brief)))
        brief['manual_test']['execution']['status'] = 'BLOCKED'
        self.assertFalse(check_manual_test(brief))

    def test_preparation_and_verification_cannot_share_an_id(self):
        brief = self.report()
        brief['manual_test']['steps'][0]['id'] = 'prep-1'
        self.assertTrue(any('一意' in e for e in check_manual_test(brief)))

    def test_untrusted_values_are_escaped_and_image_cannot_escape_shots_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            (work / 'screenshots').mkdir()
            (work / 'outside.png').write_bytes(PNG)
            (work / 'screenshots' / 'manifest.json').write_text(json.dumps([
                {'id': 'prep-1', 'ok': True, 'path': '../outside.png'},
            ]))
            brief = self.report()
            brief['manual_test']['preparation'][0]['actual'] = '<script>alert(1)</script>'
            page = manual_test_section(brief, work)
            self.assertNotIn('<script>', page)
            self.assertIn('&lt;script&gt;', page)
            self.assertNotIn('<img', page)
            self.assertIn('保存先・形式が不正', page)

    def test_legacy_seed_and_steps_remain_renderable(self):
        with tempfile.TemporaryDirectory() as directory:
            brief = {'manual_test': {
                'seed': {'script': 'INSERT INTO items (id) VALUES (7)', 'language': 'sql'},
                'steps': [{'id': 'step-1', 'title': '一覧を開く', 'actions': ['開く']}],
            }}
            self.assertFalse(check_manual_test(brief))
            page = manual_test_section(brief, Path(directory))
            self.assertIn('INSERT INTO items', page)
            self.assertIn('NOT RUN', page)


if __name__ == '__main__':
    unittest.main()
