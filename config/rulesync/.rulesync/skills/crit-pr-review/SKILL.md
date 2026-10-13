---
name: crit-pr-review
description: 他人（または自分）の GitHub PR を crit の UI でレビューする skill。PR へ checkout して `crit pr` で差分を開き、UI 上でエージェントと壁打ちしながらコメントを書き、ユーザーが選んだコメントだけを `crit push` で PR へ投稿する。「crit で PR をレビューしたい」「PR を crit で見て壁打ちしたい」と明示されたときに使う。PR の指摘に対してコードを修正する用途は fix-review を使う。
targets:
  - claudecode
  - codexcli
---

# crit で PR をレビューする

PR を **レビューする側** として crit を使う skill。目的は次の 2 つ。

1. crit の UI で差分にコメントを付け、エージェントと壁打ち（質問・妥当性確認・代案検討）する
2. 壁打ちの結果、PR に残したいコメントだけを GitHub の PR review として投稿する

`crit` / `crit-cli` skill（APM で配布）の手順を前提にしつつ、以下のルールを **優先** する。

## 絶対に守ること

- **コードを編集しない**。この skill はレビュー専用。検証のためにファイルを読む・テストを実行するのはよいが、
  Edit / Write やコミットはしない（ユーザーが明示的に頼んだ場合を除く）。
- **`crit push` は remote への書き込み**。必ず「投稿対象の一覧」と `crit push --dry-run` をユーザーに見せ、
  明示的な OK をもらってから実行する。
- `--event approve` / `--event request-changes` はユーザーが指示したときだけ使う。既定は `comment`。
- コメントの resolve は、Step 5 でユーザーが「投稿しない」と選んだものに対してのみ行う。

## crit push の仕様（v0.19.1 時点・ソース確認済み）

`crit push` に「このコメントだけ投稿する」という選択オプションは無い。投稿対象は review file の状態で決まる。

| 種類                                         | push されるか                                                                 |
| -------------------------------------------- | ----------------------------------------------------------------------------- |
| line comment（未 resolve・`github_id` なし） | **される**（PR の inline review comment として 1 つの review にまとめて投稿） |
| line comment（resolved）                     | されない                                                                      |
| review-level comment（ファイル・行指定なし） | **されない**（local only）。全体的な壁打ちはここに書けば安全                  |
| GitHub 由来/投稿済みスレッドへの reply       | **resolve 状態に関係なく、`github_id` のない reply はすべて投稿される**       |
| 投稿済みコメントの本文をローカルで編集       | 次の push で GitHub 側も編集される（PATCH）                                   |
| PR の head が進んだ後の古いコメント          | 投稿されず `stale` として export markdown に退避される                        |

そのため次の運用にする。

- 壁打ちは「自分で作ったローカルコメントのスレッド」か「review-level comment」で行う。
- **`crit pull` で取り込んだ GitHub スレッドの中では壁打ちしない**（reply が resolve しても投稿されるため）。
  そのスレッドについて相談したいときは、同じ行に別のローカルコメントを作ってそこで話す。
- 壁打ちの reply が付いたコメントを投稿したいときは、元スレッドをそのまま push しない。
  投稿用の新しいコメントを同じ行に作り、元スレッドは resolve する（元スレッドを push すると、
  次回以降の push で壁打ちの reply まで PR に投稿される）。
- resolve 済みのコメントに `--resolve` なしで reply すると **未 resolve に戻り、push 対象に復活する**。
  resolve 済みスレッドで話を続けたら、Step 5 の前に再度 resolve する。
- `crit push --dry-run` は reply・編集・削除を表示しない。Step 5 の jq で必ず確認する。

## Step 1: 対象 PR を特定して checkout する

PR 番号または URL をユーザーの発言から取得する。無ければ確認する。

```bash
gh auth status
gh pr view <PR> --json number,title,url,author,headRefName,baseRefName,isCrossRepository
git status --short
```

- working tree に未コミットの変更がある場合は、checkout 前にユーザーへ確認する（stash するか、別 worktree を使うか）。
- 問題なければ checkout する。

```bash
gh pr checkout <PR>
```

checkout はエージェントが PR のコードを読んだりテストを実行したりして、壁打ちの根拠を確認するために行う。
crit の差分表示自体は `crit pr` が PR の merge-base..head を取得して行うので、checkout 先と差分は GitHub と一致する。

## Step 2: crit で PR を開く

`run_in_background: true` で起動し、Finish Review まで待つ（`crit` skill の Step 2 と同じ）。

```bash
crit pr <PR>
```

起動ログの URL をユーザーへそのまま伝える。devcontainer 内では `crit` ラッパーが
`crit UI (host): http://localhost:<port>` も出力するので、ホストのブラウザ用にはそちらを伝える。

既存の GitHub レビューコメントも見たい場合は、起動後に取り込む（ユーザーに要否を確認してよい）。

```bash
crit pull <PR>
```

UI に反映されない場合はブラウザをリロードしてもらう。取り込んだスレッドでは壁打ちしないことを一言添える。

複数の review session があるとコマンドが失敗するので、その場合は `crit status` で ID を確認し、以降の
`crit comment` / `crit comments` / `crit pull` / `crit push` に `--session <id>` を付ける。

## Step 3: 壁打ちのループ

ユーザーにこう伝える:

> crit の UI で気になる行にコメントしてください。質問・懸念・「これ PR に書くべき？」など何でも OK です。
> 終わったら Finish Review を押してください。全体的な話は review-level comment に書くと PR には投稿されません。

（devcontainer で `agent_cmd` が設定されていれば、各コメントの「Send now」で即時に別エージェントの回答も得られる。）

`crit` が終了したら stdout（または `crit comments --json`）で未 resolve コメントを読み、各コメントに **reply で** 答える。

- 根拠となるコード・テスト・ドキュメントを実際に読んでから答える。推測なら推測と書く。
- 指摘が PR に投稿する価値がありそうなら、その旨と投稿用の文面案を reply に含める。
- 返信は `crit comment --reply-to <id> --author 'Claude Code' '<body>'`。複数あるときは `--json --file` でまとめる。
- エージェント側から気付いた点を追加してよい（`crit comment --author 'Claude Code' <path>:<line> '<body>'`）。
  ただしエージェントが作った line comment も未 resolve なら push 対象になるので、Step 5 で必ず選別する。
- `crit pull` 由来（`github_id` あり）のスレッドには reply しない。必要なら同じ行に新しいローカルコメントを作る。

返信し終えたら、再度 `crit pr <PR>`（または crit の finish prompt が示すコマンド）をバックグラウンドで実行して次の
Finish Review を待つ。ユーザーが「投稿に進む」「PR にコメントしたい」と言うか、コメントなしで Finish Review したら Step 4 へ。

## Step 4: 投稿するコメントを選ぶ

未 resolve のコメントを一覧にして、ユーザーに「PR に投稿する / しない」を選んでもらう。

```bash
crit comments --json
```

表示する項目: コメント ID、`path:line`、作成者、本文の要約、reply の有無、投稿用文面案。
既定はすべて「投稿しない」とし、ユーザーが選んだものだけを投稿対象にする。

選択結果に応じて review file を整える。

| ケース                                   | 対応                                                                                                                              |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| 投稿する・reply なし・本文そのままで良い | そのまま残す                                                                                                                      |
| 投稿する・reply あり、または文面を直す   | 同じ `path:line` に投稿用の新しいコメントを作成し、元のコメントは `--resolve` 付き reply で resolve する                          |
| 投稿しない                               | `--resolve` 付き reply で resolve する（例: `crit comment --reply-to <id> --resolve --author 'Claude Code' 'PR には投稿しない'`） |

投稿用コメントの文面はユーザーに確認してもらう。`--author` はユーザー名（`git config user.name`）を使い、
GitHub へは `gh` で認証したユーザーとして投稿されることを伝える。
GitHub 側のコメントに AI 作成である旨を入れるかはユーザーに確認する。

## Step 5: 投稿内容を確認する

review file のパスを取得し、push で GitHub に書き込まれるものを列挙する（dry-run が表示しない reply も含む）。

```bash
review_file=$(crit status --json | jq -r '.review_file')
jq -r '
  (.files // {} | to_entries[] | .key as $p | .value.comments[]? |
    ( select((.resolved | not) and .github_id == null and .dom_anchor == null)
      | "NEW-COMMENT  \($p):\(.start_line)-\(.end_line) [\(.id)] replies=\(.replies // [] | length) \(.body | split("\n")[0])" ),
    ( select(.github_id != null) | .id as $root | .replies[]? | select(.github_id == null)
      | "NEW-REPLY    \($p) [\($root)] \(.body | split("\n")[0])" )),
  (.review_comments[]? | select(.resolved | not) | "LOCAL-ONLY   (review) [\(.id)] \(.body | split("\n")[0])")
' "$review_file"
crit push --dry-run <PR>
```

- `NEW-COMMENT` が Step 4 で選んだものと一致していること（`replies` が 0 であること）を確認する。
- `NEW-REPLY` が意図しない内容なら、UI からその reply を削除してもらってから再確認する。
- dry-run の `stale` / `full-stack` は投稿されない。PR に新しい push があった場合は `crit pr <PR>` を開き直す。

一覧と dry-run の結果をユーザーに見せ、投稿してよいか明示的に確認する。

## Step 6: PR へ投稿する

```bash
crit push <PR>                                   # comment（既定）
crit push -m '<review summary>' <PR>             # review 全体のコメントを付ける場合
crit push --event request-changes -m '<msg>' <PR> # ユーザーが指示した場合のみ（message 必須）
crit push --event approve -m '<msg>' <PR>         # ユーザーが指示した場合のみ
```

投稿後は PR の URL を伝える。投稿したコメントには `github_id` が記録されるので、以降そのスレッドに reply すると
次の push で投稿される点を伝える。

## 後片付け

- レビューを続けるなら Step 3 に戻る。相手が修正を push した後は `crit pr <PR>` で開き直し、`crit pull <PR>` で
  返信を取り込む。
- 終わったら、ユーザーに確認したうえで元のブランチへ戻る（`git switch -`）。
