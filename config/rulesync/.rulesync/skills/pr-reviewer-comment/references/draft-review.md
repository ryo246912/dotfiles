# draft レビューの投稿と submit 用の本文例

pr-reviewer-comment / pr-reviewer-comment-crit skill の共通手順。

## インラインコメントの書式

```markdown
**以下、AIによる返信**
[<区分>] <一言>

<本文>
```

先頭の行より上は、ユーザーが後から自分のコメントを書き足す場所になる。本文は作成者に向けて書く（理由、起きる条件、直し方の案）。コードの提案は短いコードブロックで添える。

## 投稿のしかた

pr-reviewer-comment skill の `scripts/post_draft_review.py` を使う（この references/ と同じ pr-reviewer-comment skill の中にある）。次の 3 つをまとめて行う。

- 指定した行が diff にあるかを検査する
- 同じユーザーの PENDING のレビューが既にあれば止める（GitHub は 1 人 1 件しか持てない）
- `event` を付けずに作成する（PENDING のまま。submit しない）

```bash
python3 <pr-reviewer-comment skill のディレクトリ>/scripts/post_draft_review.py \
  --repo <owner/name> --pr <N> --input <comments.json> --dry-run   # 検査だけ
python3 <pr-reviewer-comment skill のディレクトリ>/scripts/post_draft_review.py \
  --repo <owner/name> --pr <N> --input <comments.json>             # 投稿
```

`comments.json` はスクラッチパッドなどの一時ディレクトリに置く。先に `--dry-run` で通してから投稿する。

`comments.json` の形:

```json
{
  "commit_id": "<head の SHA>",
  "comments": [
    {
      "path": "app/usecases/orders.py",
      "start_line": 120,
      "line": 128,
      "body": "**以下、AIによる返信**\n[should] ..."
    }
  ]
}
```

- 1 行だけなら `start_line` を省く
- **指摘の対象が diff の外の行**なら、インラインには付けられない。関連する diff 内の行（PR が追加した処理やコメント）に付け、本文で本来の場所（`path:line`）を示す。適当な行が無ければ submit 本文に回す
- 既に PENDING のレビューがあれば、新しく作らずにユーザーへ伝える。ユーザーが同意したら、GraphQL の `addPullRequestReviewThread` で既存の PENDING に足す
- 投稿後に文面を直すときは、**まず今の本文を取り直す**（ユーザーが手で直していることがある）。そのうえで GraphQL の `updatePullRequestReviewComment` で更新する

投稿したら、レビューの URL（`html_url`）と、付けた行の対応表（No・区分・ファイル:行）を報告する。diff の外の指摘をどこに付け替えたかも書く。

## submit 用の本文例

次の書式で出す。ユーザーはこれを土台に submit の画面で仕上げる。

```markdown
<ユーザーの入力欄>

must/shouldは対応確認お願いしたいです。imo/nitsの対応要否はお任せします
以下、確認した評価観点です。

**動作確認**

- [x] <3 で書いた手順のうち、確かめた項目。1 項目 1 行>

**コード観点**

- [x] 「<裏取りで成り立たなかった候補>」は確認の結果、成り立たない (`path:line`)
- [ ] <投稿した指摘> → <区分>でコメント (`path:line`)
```

- 動作確認の項目は、ユーザーが実際に行ったものに合わせて直してもらう前提で、3 の手順から起こす。行っていない項目を `[x]` にしない
- 「成り立たない」項目は、2 で控えた候補から、作成者やほかのレビュアーが気にしそうなものを選ぶ
- 投稿していない指摘（☓ で見送ったものなど）は書かない
- must/should が 0 件なら、定型文の 1 行目は「imo/nitsの対応要否はお任せします」だけにする
- submit の種別（Approve / Comment / Request changes）の目安を一言添える。決めるのはユーザー
