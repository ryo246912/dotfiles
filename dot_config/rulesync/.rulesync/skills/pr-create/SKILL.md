---
name: pr-create
description: 現在のブランチを push し、repo ごとの PR template と diff を根拠に PR 本文を組み立てて `gh pr create` まで行う skill。`変更内容概要` `実装理由` `確認項目` を簡潔に整理したいときに使う。
targets:
  - claudecode
  - codexcli
---

# PR の作成

## 概要

現在のリポジトリで preflight を行い、PR template と git diff を根拠に本文を組み立てて、branch push と `gh pr create` まで完了します。

## ワークフロー

### 1. Preflight

- 現在の branch と working tree を確認する。

```bash
git branch --show-current
git status --short
```

- `gh` が使えること、repo の default branch が取得できることを確認する。

```bash
gh auth status
gh repo view --json nameWithOwner,defaultBranchRef --jq '{repo: .nameWithOwner, base: .defaultBranchRef.name}'
```

- upstream と base branch との差分を確認する。remote fetch ができない環境では、`origin/<base>` が stale かもしれないことを明記する。

```bash
git rev-parse --abbrev-ref --symbolic-full-name @{u}
git rev-list --left-right --count HEAD...origin/<base>
```

- 以下では続行しない。
  - detached HEAD
  - default branch 上で直接 PR を作ろうとしている
  - base branch に対する ahead が 0
  - 未コミットの tracked / staged / untracked 変更があり、PR に含める内容が固まっていない
  - `gh` が未認証、または network / permission 不足で PR 作成まで完了できない

- default branch が `gh repo view` で取得できない場合は、`refs/remotes/origin/HEAD` を参照する。それも無ければ `main` を暫定値にし、その根拠を本文作成メモに残す。

### 2. PR template と diff の収集

- PR template は以下の順で探索する。
  - `.github/pull_request_template.md`
  - `.github/PULL_REQUEST_TEMPLATE.md`
  - `docs/pull_request_template.md`
  - `docs/PULL_REQUEST_TEMPLATE.md`
  - `pull_request_template.md`
  - `PULL_REQUEST_TEMPLATE.md`
  - `.github/PULL_REQUEST_TEMPLATE/*.md`

- `.github/PULL_REQUEST_TEMPLATE/*.md` が複数ある場合は、変更ファイルの領域や template 名の意味を見て最も近いものを選ぶ。判断材料が薄い場合は、最も汎用的な名前の template を優先し、それでも差が無ければファイル名昇順の先頭を使う。

- PR 本文の根拠として、最低限以下を確認する。

```bash
git diff --stat origin/<base>...HEAD
git diff --find-renames origin/<base>...HEAD
git log --oneline origin/<base>..HEAD
```

- 差分量が大きいときは、`git diff --name-only` や主要ファイルごとの hunk を見て変更の塊を整理する。rename や format-only のような機械的変更は、本文では必要以上に言い換えない。

### 3. PR タイトルと本文を作る

- PR title は branch 全体の目的が最短で伝わる 1 行にする。単一コミットで十分に明快なら、最後の commit subject をそのまま候補にしてよい。

- 本文は PR template を骨格として使う。template に同等の見出しがあるなら、その見出しに寄せて埋める。template に無い場合だけ、最低限次の 3 セクションを追加する。

```md
## 変更内容概要
- ...

## 実装理由
- ...

## 確認項目
- [ ] ...
```

- `変更内容概要` には diff をそのまま読み上げず、reviewer が先に掴むべき変更の塊だけを書く。
- `実装理由` には、設計意図、制約、採用しなかった代替案、cross-file の関係など、コードだけでは把握しづらい背景を書く。
- `確認項目` には、実施した確認、reviewer に見てほしい観点、未実施ならその理由を書く。
- コードを見れば明らかな追加・削除・rename は冗長に説明しない。非自明な変更、全体像が見えにくい変更、運用影響がある変更だけ補足する。
- template の placeholder、未記入の TODO、実際の diff と矛盾する文面は残さない。該当なしの必須項目は `なし` や `N/A` で明示する。

### 4. Push する

- upstream が無ければ push 先 remote を決める。明示指定が無い場合は `origin` を優先する。

```bash
git push -u <remote> <branch>
```

- upstream が既にある場合は通常の push を使う。

```bash
git push
```

- push 前に working tree が dirty なら、PR に入らない差分がある状態なので止まる。自動 commit を前提にしない。

### 5. PR を作成または更新する

- まず current branch に紐づく既存 PR の有無を確認する。

```bash
gh pr list --head "<branch>" --json number,url,title --jq '.[0]'
```

- 既存 PR がある場合は duplicate を作らず、必要なら `gh pr edit` で title / body を更新する。

```bash
gh pr edit <number> --title "<title>" --body-file "<body-file>"
```

- 既存 PR が無い場合は、base branch と本文ファイルを指定して作成する。assignee 指定の既定値は `@me` とする。

```bash
gh pr create --base "<base>" --title "<title>" --body-file "<body-file>" --assignee "@me"
```

- 作成後に `gh pr view --json number,url,title,body` などで結果を確認し、title / body / base が意図通りかを見直す。

### 6. 仕上げ

- 最終報告には以下を含める。
  - 使用した base branch
  - 使用した PR template の path、または template 不在 fallback を使ったこと
  - push 先 remote / branch
  - 作成または更新した PR の URL
  - 本文で特に文章化した非自明ポイント

- blocker がある場合は、どの preflight で止まったか、なぜ `push` / `gh pr create` が完了できないかを簡潔に示す。
