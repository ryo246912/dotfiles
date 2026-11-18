# 段階3: behaviorで準備・動作確認を行い、briefへ取り込む

通常のPR・stackで段階2の後に実行する。チケット・監視モードや「説明だけ」の指定では実操作せず、確認計画はNOT RUNのまま残す。

## 0. 実操作の許可モードを確認する

メインの依頼文とtarget.jsonの`behavior_mode`・`behavior_skip_reason`を最初に確認する。
どちらかがskip、チケット、監視、「説明だけ」ならbehaviorを起動しない。ブラウザ操作・データ作成・設定補完・知見保存はせず、計画をNOT RUNのまま残し、lesson_captureを`NOT_RUN`と省略理由で記録する。
実行モードが未指定・矛盾している場合も実操作せず、モード未確認としてメインへ返す。executeが確認できる場合だけ以降へ進む。

## 1. pr-reviewer-behaviorを使う

利用環境に配布された `pr-reviewer-behavior/SKILL.md` を読み、その手順を実行する。利用できない場合はBLOCKEDとし、理由と手動確認の開始条件をbriefへ記載する。
対象PR、`target.json`、固定したhead SHA、`brief.json`の`manual_test`、確認先URL、stack全体の変更範囲を渡す。
stackでは最上位PRの環境を使い、briefと同じstack全体を確認対象にする。

behaviorに次を依頼する。

- 起動済みのlocal／previewと、AIが接続しているChromeで、確認データの準備・画面への到達・実操作まで進める。
- behaviorの設定先・許可範囲・接続先検証・SHA確認・localのみのDB直接編集・秘密値除外・知見の個別保存をそのまま守る。環境起動や独立したChromiumの起動はしない。独立したPlaywrightのブラウザを別途起動して撮影しない。
- 準備・確認の各ステップを実行時に記録し、操作説明の直下に貼るための画像を一操作ずつ撮る。認証入力や秘密値は撮影しない。
- 必要なログイン・設定が不足したらbehaviorの手順で確認・引き継ぎを行う。実施できた範囲を保存し、不足条件だけBLOCKEDとする。
- behavior自身のHTMLに加え、briefへ転記する準備手順・実在するデータ・操作・期待結果・実結果・判定・画像・各画像が示す`records`（`ui`・`table`・`record`・`column`）・`caution`・未確認事項・削除手順を構造化して引き継ぐ。HTMLから文字列をスクレイピングせず、観測記録からJSONを作る。

## 2. brief.jsonへ結果を取り込む

`manual_test.execution`、`preparation`、`data`、`steps`、`cleanup`を更新する。PASS／FAILのステップが1件でもあれば全体がBLOCKEDでもexecutionとhead_shaを必須にし、briefの固定SHAと一致させる。異なるSHAの観測は別記録として保持し、現行版の結果には混ぜない。環境・アカウント・画像に秘密値を含めない。
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
  "pending": [],
  "image_note": "",
  "records": [
    { "ui": "一覧の名前", "table": "items", "record": "id=7 / 確認用データ", "column": "name" }
  ]
}
```

データを映す画像のある`preparation`・`steps`には、`records`を必ず転記する。記録がなければ`background.data_model.mapping`、コード、観測したID・表示値から補う。対応を確認できない場合は推測せず、当該ステップの`pending`に未確認の対応関係と理由を書く。DBとは無関係な画面では`records`を省いてよい。
削除等の元に戻せない操作は、専用テストデータと`caution`を段階2から保持し、実行時の対象と一致させる。

準備と確認のIDは全体で一意にする。一つの要素に複数操作を詰め込まず、撮影した状態と一致させる。
撮影できなかった場合は`image_note`へ理由を記載する。未実行の項目はNOT RUNまたはBLOCKEDとし、スクリーンショットがあるだけではPASSにしない。
`actual`には確認できた事実だけを書く。契約やロール・SHA・flag等の未確認条件は`pending`へ分け、次に何を確認すればよいかを箇条書きにする。実結果の文末に「ただし未確認」とまとめない。例えば「パネルの表示を確認」はactual、「契約の有無を管理画面で確認する」「起動中のSHAを確認する」はpendingに分け、条件が不足していればBLOCKEDとする。
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

## 5. 終了前の知見保存を確認する（BLOCKEDでも必須）

途中で環境へ接続できずBLOCKEDになった場合も、この確認を省略しない。終了判定の前にbehaviorの知見保存手順を実施する。

- 今回の再利用可能な知見を整理し、実行時に確定した設定先に隣接する`lessons/`へ1知見1ファイルで保存したか。
- 書き込んだファイルを読み直し、タイトル・対象リポジトリ・環境・根拠・本文が保存されたことを確認したか。subagentの「保存した」という要約だけでは完了にしない。メインも引き継がれたファイルの存在と該当箇所を確認する。
- 重複または新規知見なしの場合は`NO_CHANGE`と理由を記録したか。BLOCKEDでも、確認できた到達条件や接続上の制約は知見候補になるが、未確認の原因を断定して残さない。
- 保存を試して失敗した場合は`FAILED`と、試行内容・観測したエラー・続行条件を記録したか。書き込み可能な設定先を確保できず未試行なら`NOT_RUN`と未試行の理由を記録する。「未実施」と「書き込み失敗」を区別し、勝手に別の保存先へ散らさない。

`manual_test.lesson_capture`に`status`、`files`、`note`を残し、HTMLを再生成する。
`files`の基準は今回behaviorが選択したconfig.mdの実体ディレクトリで、知見一覧の`path`と同じ `lessons/owner/repo/要点.md` 形式にする。workやbrief.jsonの場所を基準にしない。
メインはbehaviorの `references/lesson-format.md` の「最終パスの実体検査」を、絶対パス・相対パスの両方へ適用する。相対参照なら `(Path(config).resolve(strict=True).parent / file).resolve(strict=True)` とし、設定ファイルだけでなく最終ファイル全体を解決する。絶対参照も `Path(file).resolve(strict=True)` を使う。
対象repoの許可ディレクトリは今回のowner/repoから独立に確定し、owner/repoディレクトリのsymlinkは拒否する。最終実体がその対象repoの実体配下であることを `is_relative_to` で確認し、さらに `resolved.parent == expected_repo.resolve(strict=True)`、`resolved.is_file()`、`resolved.suffix == ".md"` をすべて検査してから読み直す。対象repo直下の通常のMarkdownファイルだけを許可し、ネストしたファイルやMarkdown以外は読まない。同じlessons内の別repoや、worktree外へ出るsymlinkも読み取らない。
未存在・解決エラー・範囲外・ファイルでない場合は保存確認を失敗として扱い、本文を読まず、SAVEDと記録しない。検査を通った実体だけ、lessonsの実体からの相対部分に `lessons/` を付けてfilesへ転記する。絶対パスをそのままfilesへ渡したり、相対参照だけ検査を省略したりしない。

```json
{
  "status": "SAVED",
  "files": ["lessons/example-org/example-app/preview-login.md"],
  "note": "今回の設定先から解決したファイルを読み直し、保存を確認した"
}
```

メインはこの記録と保存先の確認結果がそろってから完了を返す。実操作を省略したモードでは`NOT_RUN`とし、知見保存を実施したように書かない。

## 終わり方

最後に1行で、更新したHTMLのパス、全体の状況、実行済み／未確認の件数、知見保存の判定を返す。
