---
name: crit-pr
description: >-
  他人の GitHub PR を crit の UI でレビューする skill。PR へ checkout し、指摘候補（must/should/imo/nit/Q）を
  裏取りしたうえで crit のインラインコメントとして並べ、`crit pr` の UI でユーザーと壁打ちする。選ばれた指摘だけを
  未 submit の draft レビューとして投稿し、submit 用の本文例まで出す。「crit で PR をレビューしたい」
  「PR を crit で見て壁打ちしたい」と crit を使う指定があるときに使う。crit を使わない PR レビューは review-pr、
  自分の PR に付いた指摘への対応は fix-review を使う。
targets:
  - claudecode
  - codexcli
---

# crit-pr — crit の UI で PR をレビューし、draft を投稿する

レビュアーとして他人の PR を読み、**指摘候補を crit に並べる → UI で壁打ちする → ユーザーが選ぶ → draft を投稿する**
までを進める。review-pr skill と同じ観点・書式で進め、壁打ちの場を crit の UI にしたもの。
submit（Approve / Comment / Request changes）はユーザーが自分で行う。指摘の取捨と最終的な文面の責任はユーザーにあり、
この skill は判断材料をそろえて下書きを作る役に徹する。

全体の流れ:

1. PR の情報を集め、PR の head へ checkout する
2. コードを読み、指摘候補を洗い出して裏を取る
3. 動作確認手順を書く
4. 指摘候補を crit のコメントとして並べ、表と一緒に出す
5. crit の UI でユーザーと壁打ちし、投稿する No を決めてもらう
6. 選ばれた No を draft レビューとして投稿し、submit 用の本文例を出す

## 共通手順の読み込み

観点・書式・投稿方法は review-pr skill と共通で、review-pr の `references/` にある。rulesync で同じ skills
ディレクトリに配置されるので、`<この skill のディレクトリ>/../review-pr/references/` を手順に入るときに読む。
以下ではこのディレクトリを `<refs>` と書く。

| 手順 | 読むファイル             | crit-pr で追加・変更すること           |
| ---- | ------------------------ | -------------------------------------- |
| 1    | `<refs>/pr-info.md`      | checkout と HEAD の確認（下記 1）      |
| 2, 4 | `<refs>/findings.md`     | 候補を crit のコメントにする（下記 4） |
| 3    | `<refs>/manual-test.md`  | なし                                   |
| 6    | `<refs>/draft-review.md` | crit のコメントから作る（下記 6）      |

`crit` / `crit-cli` skill（APM で配布）の CLI の使い方も前提にする。

## 1. PR の情報を集め、checkout する

`<refs>/pr-info.md` に従う。そのうえで、working tree に未コミットの変更があれば、checkout 前にユーザーへ確認する
（stash するか、別 worktree を使うか）。問題なければ checkout し、手元の HEAD が PR の head と一致することを確かめる。

```bash
git status --short
gh pr checkout <N>
git rev-parse HEAD   # headRefOid と一致すること
```

crit のコメントの行番号は**手元のファイルの行番号**なので、HEAD が head の SHA と一致していないと投稿時に行がずれる。

## 2. 指摘候補を洗い出し、裏を取る

`<refs>/findings.md` に従う。検証のためにファイルを読む・テストを実行するのはよいが、**コードは編集しない**
（ユーザーが明示的に頼んだ場合を除く）。

## 3. 動作確認手順を書く

`<refs>/manual-test.md` に従う。手順はターミナルに出す。crit 上でも見たいとユーザーが言えば、review-level comment
（行指定なし）として追加する。

## 4. 指摘候補を crit に並べ、表と一緒に出す

### crit を起動する

`run_in_background: true` で起動する（`crit` skill の Step 2 と同じく、Finish Review まで終了しない）。

```bash
crit pr <N>
```

`crit pr` は PR の merge-base..head を差分として開くので、表示は GitHub と一致する。起動ログの URL をユーザーへそのまま伝える。
devcontainer 内では `crit` ラッパーが `crit UI (host): http://localhost:<port>` も出力するので、ホストのブラウザ用にはそちらを伝える。
複数の review session があると CLI が失敗するので、その場合は `crit status` で ID を確認し、以降の `crit comment` /
`crit comments` に `--session <id>` を付ける。

### 指摘候補をコメントとして追加する

各候補を、対象コードの行に line comment として追加する。本文の 1 行目は `No.<n> [<区分>] <一言>` にして、
crit の UI と表を No で対応させる。複数行の本文は JSON をファイルに書いて `--json --file` で一括追加する。

```json
[
  {
    "file": "app/usecases/orders.py",
    "line": "120-128",
    "body": "No.1 [should] 更新処理がロックを取っていない\n\n**本PRとの関係**: △ 処理自体は既存だが、PR が足した整合性の保証が同時実行で崩れる\n\n**理由**: <起きる条件と結果>\n\n**関連コード**: `app/models/order.py:45`"
  }
]
```

```bash
crit comment --json --file <comments.json> --author 'Claude Code'
```

- 対象が diff の外の行でも、ファイル上の行に付けてよい（投稿時に付け替える。`<refs>/draft-review.md` を参照）
- 行に付けられない指摘（PR 全体への意見など）は review-level comment（`file` も `line` も付けない）にする

### ターミナルにも表と詳細を出す

`<refs>/findings.md` の「出し方」に従う。crit の UI では対象行が見えているので、コメント本文にはコードを貼らなくてよい。

## 5. crit の UI で壁打ちし、投稿する No を決めてもらう

表を出したら、ユーザーにこう伝えて**止まる**。投稿する No が決まるまで、何も投稿しない。

> crit の UI で各指摘にリプライして、質問・反論・文面の相談をしてください。気になる行には新しいコメントも付けられます。
> 書き終えたら Finish Review を押してください。何往復でもできます。
> 壁打ちを終えるときは、コメントなしで Finish Review するか「投稿に進む」と伝えてください。

### 壁打ちのやり方: Finish Review を往復する

壁打ちは **Finish Review の往復**で行う。1 回の Finish Review で、その時点の未 resolve のコメントとリプライがまとめて
この会話のエージェントに渡り、エージェントが各スレッドにリプライしてから次の Finish Review を待つ。これを何回でも繰り返せる。

`crit` が終了したら stdout（または `crit comments --json`）で未 resolve のコメントを読み、各スレッドに **reply で** 答える。

- 根拠となるコード・テスト・ドキュメントを実際に読んでから答える。推測なら推測と書く
- 返信は `crit comment --reply-to <id> --author 'Claude Code' '<body>'`。複数あるときは `--json --file` でまとめる
- ユーザーが新しく付けたコメントは、内容で扱いを分ける
  - PR への指摘（作成者に伝えたいこと）→ 指摘候補として裏取りし（`<refs>/findings.md`）、No・区分・本 PR との関係を付けて表に足す
  - エージェントへの質問（「ここは何をしている？」など）→ reply で答えるだけで、候補にはしない
  - どちらか判断できなければ、reply で「PR への指摘として候補に足しますか？」と聞く
- 壁打ちで指摘が誤りと分かったら、表から外したことを明言し、そのコメントにその旨を reply する
  （resolve はユーザーが UI で行う。`--resolve` はユーザーに頼まれたときだけ付ける）

### ラリーごとに候補の表を出し直す

候補は、最初に洗い出したもの（2）と、壁打ちで増えたもの（ユーザーの新しい指摘）を合わせたもの。
**1 往復ごとに**、reply を終えた時点の最新の表をターミナルに出し、表の下に前回からの変更を箇条書きにする
（追加した No、外した No とその理由、区分・本 PR との関係・一言を変えた No）。変更が無ければ「変更なし」と書く。
No は振り直さない（外した No は欠番にする）。crit 上の元のコメント本文は書き換えないので、最新の内容は表を正とする。

表を出したら、再度 `crit pr <N>` をバックグラウンドで実行して次の Finish Review を待つ（2 回目以降は前のラウンドの
完了を crit に伝えてから待つので、ユーザーはブラウザでそのまま続けられる）。

### 壁打ちを終えて、投稿する No を決めてもらう

ユーザーが「投稿に進む」と言うか、コメントなしで Finish Review したら（crit ではこれが approve 扱い）、壁打ちを終える。
次を出して**止まり**、投稿する No を選んでもらう。

- 最終の表
- No ごとの投稿本文案（下の「resolve と投稿の関係」のとおり、スレッド全体を踏まえて書き直したもの。
  `<refs>/draft-review.md` のインラインコメントの書式で書く）

ユーザーが No を選び、本文案を確認したら 6 へ進む。本文の修正を頼まれたら直して出し直す。

### resolve と投稿の関係

投稿するかどうかは**ユーザーが指定した No で決まり、crit 上の resolve の有無とは関係ない**（`crit push` を使わないため）。
resolve は「このスレッドはもう話さない」という意味だけを持つ。resolve したコメントは次の Finish Review でエージェントに
渡らなくなるので、まだ相談したいスレッドは resolve しない。

投稿する本文は、**最初のコメントをそのまま使うのではなく、スレッド全体（リプライでの質問と回答）を踏まえた結論で書き直す**。

- 壁打ちで理由・起きる条件・直し方の案が変わったり補われたりしたら、それを反映する
- 区分や一言が変わったら、表とあわせて直す
- 質問への回答で懸念が解消し、指摘ではなく確認事項になったなら区分を Q にするか、投稿しないことをユーザーに提案する
- 書き直した本文は、壁打ちを終えたときに No ごとの投稿本文案として出し、ユーザーに確認してもらう

## 6. draft レビューを投稿し、submit 用の本文例を出す

`<refs>/draft-review.md` に従う。crit-pr では次の点を加える。

- `crit push` は使わない。`crit push` は event 付き（既定は COMMENT）でレビューを作るため投稿した時点で submit され、
  draft にできない。また resolve の有無に関係なく GitHub 上のスレッドへの reply まで投稿する
- `comments.json` は、選ばれた No の crit のコメントの `file`・`start_line`・`end_line`（`crit comments --json` で確認）から作る
- 本文は 5 の「resolve と投稿の関係」のとおり、スレッド全体を踏まえた結論で書く。壁打ちの経緯や crit 上の reply はそのまま載せない
- ユーザーが自分で書いたコメントをそのまま投稿したいと言った場合は、`**以下、AIによる返信**` を付けずにその本文を使う
- 投稿前に `git rev-parse HEAD` が PR の head と一致していることを確かめる。PR に新しい push があったら、
  `gh pr checkout <N>` で取り直し、行番号を数え直す
- 投稿後、crit 側のコメントは、ユーザーに確認したうえで投稿済みのものに `投稿済み（draft）` と reply し、`--resolve` で閉じてよい

## 後片付け

- 相手が修正を push した後に再レビューするなら、`gh pr checkout <N>` で取り直して `crit pr <N>` を開き直す
- 終わったら、ユーザーに確認したうえで元のブランチへ戻る（`git switch -`）

## してはいけないこと

- レビューを submit しない（`crit push`、`event` を付けた投稿、`submit_pending` の実行を含む）
- 他人のブランチへの commit / push、他人のスレッドへの返信、ラベルや状態の変更をしない
- コードを編集しない（検証のための読み取り・テスト実行は可）
- 裏を取っていない候補を crit や表に載せない
