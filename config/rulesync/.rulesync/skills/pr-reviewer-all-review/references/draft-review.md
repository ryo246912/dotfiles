# レビューの投稿と submit 用の本文例

pr-reviewer-all-review / pr-crit skill の共通手順。

## インラインコメントの書式

見出し「以下、AIでの返信」は必ず `**` で囲み、Markdown の太字にする。

```markdown
**以下、AIでの返信**
[<区分>] <一言>

<問題が起きる条件と影響>

**推奨対応案**: <どこをどう変えるか。対処できる理由や、必要な確認>
```

先頭の行より上は、ユーザーが後から自分のコメントを書き足す場所になる。本文は作成者に向けて書く。候補の詳細と壁打ちで合意した内容を踏まえ、各指摘に推奨対応案を含める。Q の扱いは `findings.md` に従う。コード例が役に立つ場合は、短いコードブロックで添える。

本文でコミット・PR・Issue を参照するときは、GitHub が自動でリンクにする書式で書く（HTML の `<a>` タグや Markdown のリンク記法は使わない）。

- コミット: SHA をそのまま書く（7 文字以上）。別リポジトリなら `owner/repo@<SHA>`
- PR・Issue: `#123`。別リポジトリなら `owner/repo#123`
- SHA や `#123` の前後には半角スペースを入れる（日本語や全角括弧と隣り合うとリンクにならない）
- SHA や `#123` をバッククォートで囲まない（囲むとリンクにならない）

## 投稿のしかた

pr-reviewer-all-review skill の `scripts/post_draft_review.py` を使う（この references/ と同じ pr-reviewer-all-review skill の中にある）。次の 3 つをまとめて行う。

- 指定した行が diff にあるかを検査する
- 同じユーザーの PENDING のレビューが既にあれば止める（GitHub は 1 人 1 件しか持てない）
- 通常は `event` を付けずに PENDING として作成する。公開指定時は `event` を付け、1 回の API 呼び出しで公開する

```bash
python3 <pr-reviewer-all-review skill のディレクトリ>/scripts/post_draft_review.py \
  --repo <owner/name> --pr <N> --input <comments.json> --dry-run   # 検査だけ
python3 <pr-reviewer-all-review skill のディレクトリ>/scripts/post_draft_review.py \
  --repo <owner/name> --pr <N> --input <comments.json>             # 投稿
```

`comments.json` はスクラッチパッドなどの一時ディレクトリに置く。先に `--dry-run` で通してから投稿する。

### 公開指定がある場合

「submitして」（「submit シテ」などの表記も含む）、「submit No.1」、「No.1 を submitして」、または `--submit` が明示されたときに使う。「投稿して」の場合は通常どおり draft を作る。
投稿する No が確定していれば、ユーザーの明示した公開指定を投稿の承認として扱う。選ばれた指摘とユーザーが指定した文面の変更を反映し、レビュー全体の本文を JSON の `body` に入れる。本文案の提示や追加の OK を待たず、検査が通ったら公開する。
既定の種別は Comment。Approve / Request changes はユーザーが種別を明示したときだけ選ぶ。

通常のコマンドに `--submit` を加える。種別を指定された場合は `--submit APPROVE` または `--submit REQUEST_CHANGES` を使う。
公開前の検査では、同じ入力・種別に `--dry-run` も付ける。
既存の PENDING がある場合は公開操作を止めてユーザーに伝える。

`comments.json` の例。公開する場合はレビュー全体の本文を `body` に入れる（draft では省略可）。

```json
{
  "commit_id": "<head の SHA>",
  "body": "確認した内容と対応をお願いしたい指摘をまとめます。",
  "comments": [
    {
      "path": "app/usecases/orders.py",
      "start_line": 120,
      "line": 128,
      "body": "**以下、AIでの返信**\n[should] ..."
    }
  ]
}
```

- 1 行だけなら `start_line` を省く
- **指摘の対象が diff の外の行**なら、インラインには付けられない。関連する diff 内の行（PR が追加した処理やコメント）に付け、本文で本来の場所（`path:line`）を示す。適当な行が無ければ、推奨対応案とともに submit 本文に回す
- 既に PENDING のレビューがあれば、新しく作らずにユーザーへ伝える。ユーザーが同意したら、GraphQL の `addPullRequestReviewThread` で既存の PENDING に足す
- 投稿後に文面を直すときは、**まず今の本文を取り直す**（ユーザーが手で直していることがある）。そのうえで GraphQL の `updatePullRequestReviewComment` で更新する

投稿したら、draft か公開済みかを明示し、レビューの URL（`html_url`）と、付けた行の対応表（No・区分・ファイル:行）を報告する。diff の外の指摘をどこに付け替えたかも書く。

## submit 用の本文例

次の書式で出す。AI が作成した総評の冒頭に `**以下、AIでの返信**` を入れ、その上をユーザーの入力欄とする。

```markdown
<ユーザーの入力欄>

**以下、AIでの返信**

must/shouldは対応確認お願いしたいです。imo/nitsの対応要否はお任せします
以下、確認した評価観点です。

**動作確認**

- [x] <3 で書いた手順のうち、確かめた項目。1 項目 1 行>

**コード観点**

- [x] 「<裏取りで成り立たなかった候補>」は確認の結果、成り立たない (`path:line`)
- [ ] <投稿した指摘> → <区分>でコメント (`path:line`)
- [ ] <行に付けられなかった指摘> → <区分>。<推奨対応案>（対象コードがあれば `path:line`）
```

- 動作確認の項目は、ユーザーが実際に行ったものに合わせて直してもらう前提で、3 の手順から起こす。行っていない項目を `[x]` にしない
- 「成り立たない」項目は、2 で控えた候補から、作成者やほかのレビュアーが気にしそうなものを選ぶ
- 投稿した指摘と、ユーザーが選んだうえで行に付けられず submit 本文に回した指摘を載せる
- must/should が 0 件なら、AI 表記に続く定型文の 1 行目は「imo/nitsの対応要否はお任せします」だけにする
- 再レビューで前回の指摘への対応確認を書き添える場合も、AI 表記の下に入れる
- submit の種別（Approve / Comment / Request changes）の目安を一言添える。決めるのはユーザー
