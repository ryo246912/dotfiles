# 段階 3（頼まれたときだけ）: スクリーンショットを撮る

pr-reviewer-brief skill の段階 3。ユーザーが「スクショも撮って」などと頼んだときだけ行う。軽いモデル（Haiku）で行う前提。

入力: `<作業ディレクトリ>`（以下 `<work>`）の `brief.json`（`manual_test.steps`）と `notes.md`（動かし方）。

## 1. 撮る先の URL を決める

依頼のときに URL を渡されていればそれを使う。無ければ次の順で決める。

- **localhost（多くはこちら）**: 手元で PR の head のアプリが起動していれば、その URL（`http://localhost:<port>`）を使う。
  起動していなければ、`brief.json` の `manual_test.environment` の手順で起動してよいかユーザーに聞く
- **Preview**: PR のコメント（Vercel などの bot）と `gh api repos/<owner>/<repo>/deployments?sha=<head SHA>` → 各
  deployment の statuses の `environment_url` から探す
- どちらも決まらなければユーザーに聞く。監視モードから呼ばれたときは撮らずに、`brief.json` の `unknowns` に書く

## 2. 撮影計画を書く

`manual_test.steps` の各手順を、URL と操作に落として `<work>/shots.json` に書く。`id` は手順の `id` と同じにする
（資料の手順にそのまま貼られる）。書式は `<skill>/scripts/screenshot.py` の冒頭。

```json
{
  "base_url": "http://localhost:3000",
  "shots": [
    {
      "id": "step-1",
      "url": "/settings/profile",
      "actions": [
        { "type": "click", "selector": "role=button[name='編集']" },
        { "type": "wait_for", "selector": "text=プロフィールを編集" }
      ],
      "capture": { "selector": "main" }
    }
  ]
}
```

## 3. 撮って、HTML を作り直す

```bash
uvx playwright install chromium   # Chromium が無ければ（初回だけ）
uv run <skill>/scripts/screenshot.py --plan <work>/shots.json --out-dir <work>/screenshots
python3 <skill>/scripts/render_brief.py --workdir <work> --out <出力先の HTML>
```

Chromium を別の場所に入れているなら、`PR_REVIEWER_BRIEF_CHROMIUM` に実行ファイルのパスを入れる（`--executable-path` でも渡せる）。
失敗した手順は、エラーが手順の下に出る。セレクタの誤りなど直せる原因なら `shots.json` を直して 1 回だけ撮り直してよい
（スクリプトは自動では撮り直さない）。画像は HTML に埋め込まれるので、1 ファイルで共有できる。

## 終わり方

最後に 1 行だけ返す: `shots=<撮れた数>/<計画した数>`。
