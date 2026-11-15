# 段階3: behaviorで準備・動作確認を行い、briefへ取り込む

通常のPR・stackで段階2の後に実行する。チケット・監視モードや「説明だけ」の指定では実操作せず、確認計画はNOT RUNのまま残す。

## 1. pr-reviewer-behaviorを使う

利用環境に配布された `pr-reviewer-behavior/SKILL.md` を読み、その手順を実行する。利用できない場合はBLOCKEDとし、理由と手動確認の開始条件をbriefへ記載する。
対象PR、`target.json`、固定したhead SHA、`brief.json`の`manual_test`、確認先URL、stack全体の変更範囲を渡す。
stackでは最上位PRの環境を使い、briefと同じstack全体を確認対象にする。

behaviorに次を依頼する。

- 起動済みのlocal／previewと、AIが接続しているChromeで、確認データの準備・画面への到達・実操作まで進める。
- behaviorの設定先・許可範囲・接続先検証・SHA確認・localのみのDB直接編集・秘密値除外・教訓追記をそのまま守る。環境起動や独立したChromiumの起動はしない。この段階では旧`scripts/screenshot.py`は使わない。
- 準備・確認の各ステップを実行時に記録し、操作説明の直下に貼るための画像を一操作ずつ撮る。認証入力や秘密値は撮影しない。
- 必要なログイン・設定が不足したらbehaviorの手順で確認・引き継ぎを行う。実施できた範囲を保存し、不足条件だけBLOCKEDとする。
- behavior自身のHTMLに加え、briefへ転記する準備手順・実在するデータ・操作・期待結果・実結果・判定・画像・未確認事項・削除手順を構造化して引き継ぐ。HTMLから文字列をスクレイピングせず、観測記録からJSONを作る。

## 2. brief.jsonへ結果を取り込む

`manual_test.execution`、`preparation`、`data`、`steps`、`cleanup`を更新する。環境・アカウント・画像に秘密値を含めない。
`preparation`と`steps`の各要素は次の形式にそろえる。

```json
{
  "id": "prep-1",
  "title": "対象組織の一覧を開く",
  "url": "http://localhost:3000/items",
  "actions": ["組織選択でテスト組織を選ぶ"],
  "expected": ["対象組織の一覧が表示される"],
  "status": "PASS",
  "actual": "対象組織の一覧表示を確認した",
  "image_note": ""
}
```

準備と確認のIDは全体で一意にする。一つの要素に複数操作を詰め込まず、撮影した状態と一致させる。
撮影できなかった場合は`image_note`へ理由を記載する。未実行の項目はNOT RUNまたはBLOCKEDとし、スクリーンショットがあるだけではPASSにしない。
不一致をコードレビューの指摘として評価せず、期待と実結果の違いとして記す。
ユーザーへの引き継ぎ後も、対象SHA・準備済みデータ・開始URLから同じ手順で確認できる状態にする。

## 3. 各ステップの画像を取り込む

今回撮影して確認済みの画像のみ `<work>/screenshots/` へコピーする。別マシン上の画像は接続ツールの保存・ダウンロード機能で取得し、存在を確認する。
画像を取得できない場合は再撮影を試し、できなければ理由を`image_note`へ残す。画像や存在しないパスを捏造しない。
`<work>/screenshots/manifest.json`は次の配列とする。`path`はscreenshotsディレクトリからの相対パス。

```json
[
  { "id": "prep-1", "ok": true, "path": "prep-1.png" },
  { "id": "step-1", "ok": false, "error": "対象画面に到達できなかった" }
]
```

画像の形式・秘密値除外はbehaviorと同じ条件にする。以前の実行や別SHAの画像を今回の証拠へ混在させない。
前提知識用の画面も今回撮影できた場合だけ`page-<id>`でmanifestへ追加し、`background.pages[].shot`に対応させる。

## 4. 同じHTMLを再生成する

```bash
python3 <skill>/scripts/render_brief.py --workdir <work> --out <段階2で作ったHTML>
```

「動作確認方法」に準備、データ、実操作、実結果、判定と各画像が並ぶことを確認する。behaviorの別HTMLへのリンクだけで済ませない。
画像が無いステップは理由が表示されることを確認する。`unknowns`にも未確認項目・不足条件を追記する。
途中でPRが更新され、briefの固定SHAと今回確認したSHAが食い違う場合は、説明と結果を同じ版として混ぜない。元のSHAの記録を保持し、現行版は未確認と明記してユーザーに伝える。

## 終わり方

最後に1行で、更新したHTMLのパス、全体の状況、実行済み／未確認の件数を返す。
