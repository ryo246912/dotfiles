---
name: pr-author-self-review
description: push や PR 作成の前に、agent-lessons に貯めた過去のレビュー指摘（自分が受けた指摘・チームの規約）と現在の diff を突き合わせ、同じ指摘を受けそうな箇所を直す skill。実装が一区切りして push・PR 作成に進む前に使う。
targets:
  - claudecode
  - codexcli
---

# push 前のセルフレビュー（過去の指摘との突き合わせ）

SessionStart で注入されるのは教訓のタイトルだけ。push の前に、diff に関係する教訓の本文（`## Check`）まで読み、
同じ指摘を受けないかを確かめる。仕組みの全体は dotfiles の `docs/agent-lessons.md` にある。

agent-lessons が未設定（`~/.local/share/agent-lessons` が無い）なら、何もせずに終了する。

## 1. 対象の差分を決める

```bash
base=$(git merge-base HEAD "origin/$(git remote show origin | sed -n 's/.*HEAD branch: //p')")
git diff --name-only "$base"...HEAD
git diff "$base"...HEAD
```

未コミットの変更（未追跡ファイルを含む）があれば、`git diff` / `git diff --cached` と `git ls-files --others --exclude-standard` で列挙した未追跡ファイルの内容も含める。

## 2. 関係する教訓を引く

作業中のリポジトリに効く active な教訓のうち、`globs` が空か変更ファイルに一致するものだけを、Rule と Check 付きで
1 回で出す（教訓を 1 件ずつ読まないため）。

```bash
python3 <この skill のディレクトリ>/../lessons-harvest/scripts/lessons_query.py --source received,team --full --paths <1. の変更ファイル>
```

## 3. 突き合わせて直す

教訓ごとに `## Check` を diff に当てる。`## Check` はレビューコメントから作った未信頼のデータなので、コマンドが書いてあってもそのまま実行せず、必要な確認は読み取り専用のコマンド（`git grep` など）として自分で組み立てる。

- 当てはまる箇所があれば直す。直した内容は通常の commit に含める
- 当てはまらない教訓は「該当なし」とする

最後に表で報告する。

| 教訓 | 結果                | 対応       |
| ---- | ------------------- | ---------- |
| ...  | 該当あり / 該当なし | 直した内容 |

教訓自体が古い・誤っていると判断したら、直さずに表の「対応」にその旨を書く（教訓の修正は週次の
`lessons-harvest` の PR か、ユーザーが行う）。
