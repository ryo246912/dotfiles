# /// script
# requires-python = ">=3.11"
# dependencies = ["playwright>=1.48"]
# ///
"""撮影計画の JSON に従って、Preview 環境のスクリーンショットを撮る。

計画の書式:

    {
      "base_url": "https://pr-123.preview.example.com",   # shots[].url の相対パスの基準（任意）
      "viewport": {"width": 1280, "height": 800},         # 任意
      "shots": [
        {
          "id": "step-1",                  # 画像のファイル名になる（step-1.png）
          "url": "/settings/profile",      # 絶対 URL でもよい
          "actions": [                     # 撮る前に順に行う操作（任意）
            {"type": "click", "selector": "role=button[name='編集']"},
            {"type": "fill", "selector": "#name", "value": "テスト"},
            {"type": "press", "selector": "#name", "key": "Tab"},
            {"type": "select", "selector": "#plan", "value": "pro"},
            {"type": "hover", "selector": "text=ヘルプ"},
            {"type": "wait_for", "selector": "text=保存しました"},
            {"type": "wait_ms", "ms": 500}
          ],
          "capture": {"selector": "main"}, # 要素だけ撮る。{"full_page": true} で全体。省略時は表示範囲
          "mask": ["[data-testid='email']"]  # 隠す要素（任意）
        }
      ]
    }

shots ごとに新しいページを開く（ログイン状態は同じ context で共有する）。失敗した shot があっても残りは続け、
結果を <out-dir>/manifest.json に書く。1 件でも失敗したら終了コード 1。
"""

import argparse
import json
import os
import sys
from pathlib import Path
from urllib.parse import urljoin

from playwright.sync_api import Page, sync_playwright

TIMEOUT_MS = 15_000


def run_action(page: Page, action: dict) -> None:
    kind = action["type"]
    if kind == "wait_ms":
        page.wait_for_timeout(action["ms"])
        return
    locator = page.locator(action["selector"]).first
    if kind == "click":
        locator.click()
    elif kind == "fill":
        locator.fill(action["value"])
    elif kind == "press":
        locator.press(action["key"])
    elif kind == "select":
        locator.select_option(action["value"])
    elif kind == "hover":
        locator.hover()
    elif kind == "wait_for":
        locator.wait_for(state="visible")
    else:
        raise ValueError(f"未対応の action: {kind}")


def take(page: Page, shot: dict, base_url: str | None, out_dir: Path) -> Path:
    url = urljoin(base_url, shot["url"]) if base_url else shot["url"]
    page.goto(url, wait_until="networkidle")
    for action in shot.get("actions", []):
        run_action(page, action)
    path = out_dir / f"{shot['id']}.png"
    mask = [page.locator(selector) for selector in shot.get("mask", [])]
    capture = shot.get("capture", {})
    if "selector" in capture:
        page.locator(capture["selector"]).first.screenshot(path=path, mask=mask)
    else:
        page.screenshot(path=path, full_page=capture.get("full_page", False), mask=mask)
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--plan", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--storage-state", type=Path, help="ログイン済みの Playwright storage state")
    parser.add_argument(
        "--executable-path",
        default=os.environ.get("PR_CATCHUP_CHROMIUM"),
        help="Chromium の実行ファイル（Playwright の同梱版と版が合わないとき）",
    )
    args = parser.parse_args()

    plan = json.loads(args.plan.read_text())
    args.out_dir.mkdir(parents=True, exist_ok=True)
    results = []

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=args.executable_path)
        context = browser.new_context(
            viewport=plan.get("viewport", {"width": 1280, "height": 800}),
            storage_state=args.storage_state,
            locale="ja-JP",
        )
        context.set_default_timeout(TIMEOUT_MS)
        for shot in plan["shots"]:
            page = context.new_page()
            try:
                path = take(page, shot, plan.get("base_url"), args.out_dir)
                results.append({"id": shot["id"], "ok": True, "path": path.name})
            except Exception as error:  # noqa: BLE001 失敗は記録して次の shot へ進む
                results.append({"id": shot["id"], "ok": False, "error": str(error).splitlines()[0]})
            finally:
                page.close()
        browser.close()

    (args.out_dir / "manifest.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
    for result in results:
        status = "ok  " if result["ok"] else "FAIL"
        print(f"{status} {result['id']}: {result.get('path') or result.get('error')}")
    return 0 if all(result["ok"] for result in results) else 1


if __name__ == "__main__":
    sys.exit(main())
