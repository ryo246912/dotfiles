---
name: pr-create
description: 各リポジトリで push と draft PR 作成を進める skill。PR template 探索、diff を根拠にした本文構築、既存 PR 更新、gh CLI での公開まで必要なときに使う。
targets:
  - claudecode
  - codexcli
---

# PR 作成フロー

この skill は、実装と検証が終わった branch を push し、repo ごとの PR template と diff を根拠に draft PR を作成または更新するための手順です。

## 1. Preflight

最初に以下を確認します。

```bash
git branch --show-current
git status --short
git symbolic-ref refs/remotes/origin/HEAD | cut -d'/' -f4
git rev-list --left-right --count HEAD...origin/$(git symbolic-ref refs/remotes/origin/HEAD | cut -d'/' -f4)
gh auth status
```

- デフォルト branch 上にいる場合は、そのまま PR を作らず feature branch に切り替えます。
- `git status --short` が空でなく、まだ commit していない変更がある場合は、PR 作成前に commit まで済ませます。
- `HEAD...origin/<default-branch>` が `0 0` の場合は PR の根拠になる差分がないので停止します。
- `behind > 0` の場合は、最新の `origin/<default-branch>` を取り込んで競合解消と再検証を済ませてから続けます。
- `gh auth status` が失敗する場合は GitHub 認証を直すまで公開処理を進めません。

必要に応じて、以下も確認します。

```bash
git remote -v
gh repo view --json nameWithOwner,defaultBranchRef
gh pr list --head "$(git branch --show-current)" --state all --json number,title,url,isDraft
```

## 2. PR template を探す

まず repo 内の標準配置を探索します。

```bash
find . -maxdepth 4 \
  \( -path './.github/pull_request_template.md' \
  -o -path './.github/PULL_REQUEST_TEMPLATE.md' \
  -o -path './docs/pull_request_template.md' \
  -o -path './docs/PULL_REQUEST_TEMPLATE.md' \
  -o -path './pull_request_template.md' \
  -o -path './PULL_REQUEST_TEMPLATE.md' \
  -o -path './.github/PULL_REQUEST_TEMPLATE/*.md' \) \
  | sort
```

- 単一ファイル template が見つかったらそれを使います。
- `.github/PULL_REQUEST_TEMPLATE/*.md` 形式しかない場合は、変更内容や issue 文脈に最も近い名前を優先し、判断材料が乏しければ sort 順の先頭を使います。
- template がない場合は skill 内で最小構成の本文を組み立てます。

template を使う場合でも、見出しやチェックリストは壊さず、埋めるべき項目だけを埋めます。

## 3. PR 本文の材料を集める

本文を作る前に、差分と検証結果を確認します。

```bash
base_branch="$(git symbolic-ref refs/remotes/origin/HEAD | cut -d'/' -f4)"
git diff --stat "origin/$base_branch"...HEAD
git diff --name-only "origin/$base_branch"...HEAD
git log --oneline "origin/$base_branch"..HEAD
git diff "origin/$base_branch"...HEAD
```

- 差分ファイル一覧と diff から、変更の主目的、非自明な設計判断、確認済み項目を抽出します。
- コードを見ればすぐ分かる単純な rename、typo 修正、機械的整形は本文で冗長に説明しません。
- 一方で、全体像が見えにくい変更、fallback、運用上の前提、複数ファイルにまたがる意図は短く文章化します。

本文に含める最低限の観点:

- `変更内容概要`
  - レビュアーが最初に読むべき成果物と影響範囲
- `実装理由`
  - なぜその変更が必要か
  - なぜそのやり方を選んだか
- `確認項目`
  - 実行した test / lint / dry-run / 手動確認

template がこれらと別の見出しを持つ場合は、もっとも近いセクションへ内容を写像します。

## 4. PR 本文を書く

本文は `--body-file` 用の一時ファイルに出します。

```bash
body_file="$(mktemp -t pr-create-body.XXXXXX.md)"
```

template がない場合の最小構成は以下です。

```md
## 変更内容概要
- ...

## 実装理由
- ...

## 確認項目
- [x] ...
```

書き方のルール:

- 見たままのコード差分を箇条書きでなぞらない
- 非自明な背景、制約、fallback、影響範囲を優先して書く
- 検証項目は実際に実行した内容だけを書く
- 不確かな事項は断定せず、必要なら前提として明記する
- template に必須チェックボックスや記入欄がある場合は削除せず、未実施なら未実施と分かる形で残す

## 5. Push と PR 作成

branch を push し、既存 PR があれば更新、なければ新規作成します。

```bash
branch="$(git branch --show-current)"
base_branch="$(git symbolic-ref refs/remotes/origin/HEAD | cut -d'/' -f4)"

git push -u origin "$branch"

existing_pr="$(gh pr list --head "$branch" --state all --json number,url,isDraft --jq '.[0]')"
```

- `git push -u origin "$branch"` が失敗し、upstream 未設定が原因なら `HEAD` 指定で再実行します。

```bash
git push -u origin HEAD
```

- `existing_pr` がある場合:

```bash
pr_number="$(printf '%s' "$existing_pr" | jq -r '.number')"
gh pr edit "$pr_number" --title "<title>" --body-file "$body_file"
```

- `existing_pr` がない場合:

```bash
gh pr create --draft --base "$base_branch" --title "<title>" --body-file "$body_file"
```

title の基本方針:

- issue identifier と title がある場合は `IDENTIFIER: タイトル`
- ない場合は branch や commit 件名から、変更目的が分かる短い title を付ける

repo 運用で label が必須なら追加します。Symphony/Rondo 系 workflow では `symphony` を付けます。

```bash
gh pr edit <pr-number> --add-label symphony
```

必要なら issue URL や tracker URL を footer に含めます。

## 6. Fallback

- template 不在: 最小構成の本文を生成して続行する
- 既存 PR あり: `gh pr edit` で本文と title を更新し、新規 PR は作らない
- branch が base に追いついていない: 先に同期と再検証を済ませる
- diff が大きすぎる: file list と commit log で主目的を先に整理し、非自明な点だけを本文に残す
- PR 本文が template と競合する: template の見出し順を優先し、内容だけ差し替える

この skill のゴールは、diff をそのまま写経した PR ではなく、レビュアーが「何が重要か」「なぜそうしたか」「何を確認済みか」を最短で把握できる draft PR を作ることです。
