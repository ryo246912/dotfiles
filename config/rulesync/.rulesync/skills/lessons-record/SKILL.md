---
name: lessons-record
description: 採用したレビュー指摘やユーザーの訂正を、次の実装で同じ指摘を受けないための教訓として agent-lessons（Basic Memory）の inbox に 1 件記録する skill。pr-author-fix などで指摘を直した直後や、ユーザーに実装を訂正されたときに使う。
targets:
  - claudecode
  - codexcli
---

# 教訓を 1 件記録する

レビュー指摘を直した直後のエージェントが、**なぜその指摘を受けたか**を一番正確に言える。その場で
agent-lessons の inbox に観察（`type: lesson_observation`）として書き残す。集計・昇格・注入は
週次の `lessons-harvest` と SessionStart hook が行うので、ここでは 1 件書くだけにする。
仕組みの全体は dotfiles の `docs/agent-lessons.md` にある。

記録に失敗しても本来の作業（修正・push・返信）は止めない。失敗したことだけをユーザーに伝える。

## 記録するもの・しないもの

記録する:

- 採用して直したレビュー指摘（人間・bot のどちらでも）
- ユーザーに実装やドキュメントを訂正された内容（「違う」「全部確認して」など）
- CI で失敗し、原因を直したもの

記録しない:

- 採用しなかった指摘（誤検知・好みの違い・この PR の範囲外）
- その場限りの事情（特定のバグの詳細、一時的な環境の問題）
- 秘密情報、個人名、5 行を超えるコード片。会社のリポジトリの指摘も同じリポジトリに入るため、本文はルールと
  根本原因の要約にとどめ、元の文面やコードは根拠の URL から辿れるようにする

## 1. 項目を決める

| 項目        | 決め方                                                                                                                      |
| ----------- | --------------------------------------------------------------------------------------------------------------------------- |
| `source`    | 自分（とエージェント）の PR に付いた指摘・自分への訂正は `received`。自分がレビューで書いた指摘は `given`                   |
| `scope_key` | 作業中のリポジトリで `agent-lessons-context --scope-keys` を実行し、配列の最後（`<host>/<owner>/<repo>`）を使う             |
| `category`  | 指摘の種類を英語のケバブケースで（例: `doc-behavior-drift`、`shell-output-parsing`、`missing-test`）                        |
| タイトル    | 次に守るべきことを命令形の 1 文で（例: 「挙動を変えたら旧名称・旧挙動の記述を grep で全件更新する」）。指摘の要約は書かない |
| `globs`     | この教訓が効くファイルの glob。どこでも効くなら `[]`                                                                        |
| `evidence`  | 指摘のスレッド URL（`https://github.com/<owner>/<repo>/pull/<n>#discussion_r<id>`）。訂正ならセッションの日付と要旨         |

タイトルは一般化して書く。同じ種類のミスが別のファイル・別のリポジトリでも起きるように読めること。

## 2. inbox に書く

```bash
basic-memory tool write-note --project agent-lessons \
  --folder "inbox/<source>" \
  --title "<YYYY-MM-DD> <タイトル>" \
  --type lesson_observation \
  --content "$(cat <<'EOF'
---
status: pending
source: <received|given>
scope_key: <host>/<owner>/<repo>
category: <category>
evidence: <URL>
globs: [<glob>, ...]
---
## Rule
<タイトルと同じ 1 文。必要なら 1〜2 行の補足>

## Why
<なぜ書く時点で防げなかったか。確認しなかったこと・思い込んだこと>

## Check
<push 前に diff に対して確かめること。コマンドで確かめられるならそのコマンド>
EOF
)"
```

同じ `evidence` の観察が既にあれば書かない（`basic-memory tool search-notes --type lesson_observation --meta evidence=<URL> --project agent-lessons`）。

## 3. 同期する

```bash
mise run lessons:sync
```

commit・pull・push・再インデックスまでを行う。secretlint で止まったら、該当箇所を書き直してから再実行する。
