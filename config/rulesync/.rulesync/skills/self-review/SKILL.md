---
name: self-review
description: push や PR 作成の前に、agent-lessons に貯めた過去のレビュー指摘（自分が受けた指摘・チームの規約）と現在の diff を突き合わせ、同じ指摘を受けそうな箇所を直す skill。実装が一区切りして push・PR 作成に進む前に使う。
targets:
  - claudecode
  - codexcli
---

# push 前のセルフレビュー（過去の指摘との突き合わせ）

SessionStart で注入されるのは教訓のタイトルだけ。push の前に、diff に関係する教訓の本文（`## Check`）まで読み、
同じ指摘を受けないかを確かめる。仕組みの全体は dotfiles の `docs/agent-lessons.md` にある。

`basic-memory` が無い、または agent-lessons が未設定（`basic-memory tool list-projects` に `agent-lessons` が無い）
なら、何もせずに終了する。

## 1. 対象の差分を決める

```bash
base=$(git merge-base HEAD "origin/$(git remote show origin | sed -n 's/.*HEAD branch: //p')")
git diff --name-only "$base"...HEAD
git diff "$base"...HEAD
```

未コミットの変更があれば `git diff` / `git diff --cached` も含める。

## 2. 関係する教訓を引く

```bash
filter=$(jq -cn --argjson keys "$(agent-lessons-context --scope-keys)" \
  '{scope_key: {"$in": $keys}, source: {"$in": ["received", "team"]}}')
basic-memory tool search-notes --type lesson --status active --filter "$filter" \
  --project agent-lessons --page-size 50 --json
```

結果の `permalink` ごとに本文と frontmatter を読む。

```bash
basic-memory tool read-note <permalink> --project agent-lessons --json
```

`frontmatter.globs` が空か無いものと、`globs` が変更ファイルのどれかに一致するものだけを残す。

## 3. 突き合わせて直す

教訓ごとに `## Check` を diff に当てる。コマンドが書いてあれば実行する（例: 変更したタスク名を docs・example で grep する）。

- 当てはまる箇所があれば直す。直した内容は通常の commit に含める
- 当てはまらない教訓は「該当なし」とする

最後に表で報告する。

| 教訓 | 結果                | 対応       |
| ---- | ------------------- | ---------- |
| ...  | 該当あり / 該当なし | 直した内容 |

教訓自体が古い・誤っていると判断したら、直さずに表の「対応」にその旨を書く（教訓の修正は週次の
`harvest-review-lessons` の PR か、ユーザーが行う）。
