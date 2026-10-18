# agent-lessons（レビュー指摘から学び、同じ指摘を受けないためのループ）

PR に付いたレビュー指摘やユーザーの訂正を教訓として private リポジトリに貯め、次に実装する Claude Code / Codex へ
自動で戻す仕組み。保存と検索は [Basic Memory](https://github.com/basicmachines-co/basic-memory)、
定期実行は Claude Desktop のローカル定期タスク、注入は SessionStart hook で行う。

## 全体像

```text
 [自分の PR で採用した指摘] ─ lessons-record（直した直後に記録）─┐
 [ユーザーの訂正]           ─────────────────────────────────────┤
                                                                 ├→ inbox/（観察）
 [targets の全リポジトリの PR] ─ lessons-harvest（週次）──┘        │
   received: 自分が受けた指摘 / given: 自分が書いた指摘 / team: チーム内の指摘   │ 週次でまとめる
                                                                          ↓
                                     lessons/（教訓。candidate → active → retired）
                                       昇格・失効は agent-lessons への PR で人が確認する
                                                                          │
     ┌────────────────────────────────────────────────────────────────────┤
     ↓ SessionStart hook（タイトルを注入）  ↓ pr-author-self-review（push 前）   ↓ pr-reviewer-comment（観点）
   received + team                       received + team の Check   given + team
```

| 役割                     | 担うもの                                                                                 |
| ------------------------ | ---------------------------------------------------------------------------------------- |
| 保存・同期               | private リポジトリ（`agent-lessons`）を `~/.local/share/agent-lessons` に clone したもの |
| 検索                     | Basic Memory の project `agent-lessons`（frontmatter のメタデータで絞り込む）            |
| その場の記録             | `lessons-record` skill（pr-author-fix と COMMON.md のレビュー対応フローから呼ぶ）        |
| 週次の収集・昇格         | `lessons-harvest` skill を Claude Desktop のローカル定期タスクで実行                     |
| 注入                     | `local/bin/agent-lessons-context`（Claude Code / Codex の SessionStart hook）            |
| push 前の突き合わせ      | `pr-author-self-review` skill                                                            |
| レビュー時の観点         | `pr-reviewer-comment` / `pr-reviewer-comment-crit`（`references/findings.md`）           |
| 同期・初期設定のコマンド | `mise run lessons:setup` / `mise run lessons:sync`（`config/mise/tasks/lessons.toml`）   |

## 知見リポジトリの構成

個人と会社の知見を 1 つの private リポジトリに置く。会社のコードが残らないよう、書くのは一般化したルールと
根本原因と根拠の URL だけにし、元のコメント本文やコード片は書かない（`lessons-record` skill の「記録しないもの」）。
commit 前に secretlint を通す。

```text
agent-lessons/
  targets.yml                    # 収集する個人のリポジトリと前回の実行日
  targets.<name>.yml             # 会社などのリポジトリ（gitignore。その端末にだけ置く）
  targets.work.yml.example       # targets.<name>.yml の雛形
  inbox/<source>/                # 観察（type: lesson_observation）。1 件 1 ファイル
  lessons/<source>/<scope_key>/  # 教訓（type: lesson）
```

### scope_key（どこで効くか）

| scope_key               | 効く範囲                            | 例                              |
| ----------------------- | ----------------------------------- | ------------------------------- |
| `global`                | すべてのリポジトリ                  | `global`                        |
| `<host>/<owner>`        | その owner（会社の org など）の全体 | `github.com/acme`               |
| `<host>/<owner>/<repo>` | そのリポジトリだけ                  | `github.com/ryo246912/dotfiles` |

作業中のリポジトリの scope_key は `origin` の URL から決まる（`agent-lessons-context --scope-keys`）。
会社のリポジトリの教訓は会社のリポジトリでしか注入されない。

### source（誰の指摘か）

| source     | 内容                                       | 使う場所                                                        |
| ---------- | ------------------------------------------ | --------------------------------------------------------------- |
| `received` | 自分（とエージェント）が受けた指摘・訂正   | SessionStart の注入、pr-author-self-review                      |
| `given`    | 自分がレビューで書いた指摘                 | pr-reviewer-comment / pr-reviewer-comment-crit の観点           |
| `team`     | 自分が関わっていない PR でのチーム内の指摘 | SessionStart の注入、pr-author-self-review、pr-reviewer-comment |

### targets.yml と targets.<name>.yml

収集するリポジトリは 2 種類のファイルに分けて書く。どちらも `lessons-harvest` が読み、ファイルごとに
`last_harvest`（前回の実行日）を持つ。

| ファイル             | 書くもの             | git                                      |
| -------------------- | -------------------- | ---------------------------------------- |
| `targets.yml`        | 個人のリポジトリ     | commit する（全端末で共有）              |
| `targets.<name>.yml` | 会社などのリポジトリ | `targets.*.yml` を gitignore（端末だけ） |

雛形は dotfiles の `config/agent-lessons/`（`~/.config/agent-lessons/`）にあり、`mise run lessons:setup` が空の
agent-lessons リポジトリへ `targets.yml`・`targets.work.yml.example`・`.gitignore` を置く。会社の端末では次のようにする。

```bash
cd ~/.local/share/agent-lessons
cp targets.work.yml.example targets.work.yml   # xxx を実際の値に置き換える
```

```yaml
last_harvest:
repos:
  - repo: github.com/acme/api
    team: true
  - repo: ghe.example.com/platform/infra
    team: true
```

`team: true` のリポジトリでは、自分が関わっていない PR の指摘も集める。

### 教訓（lessons/）の形式

```markdown
---
title: 挙動を変えたら旧名称・旧挙動の記述を grep で全件更新する
type: lesson
status: active # candidate / active / enforced / retired
source: received
scope_key: global
category: doc-behavior-drift
count: 4 # 観察の数
prs: 3 # 異なる PR の数
reviewers: 2 # team のときだけ。異なる指摘者の数（名前は残さない）
first_seen: 2026-10-14
last_seen: 2026-10-16
globs: ["docs/**", "**/*.example"]
---

## Rule

挙動を変えたら旧名称・旧挙動の記述を grep で全件更新する。

## Why

挙動を変えたファイルだけを直し、同じ挙動を説明している別ファイル（docs・example・コメント）を探していなかった。

## Check

変更したタスク名・オプション名・挙動を表す語で `git grep` し、ヒットしたファイルが diff に含まれているか確かめる。

## Evidence

- https://github.com/ryo246912/dotfiles/pull/1613#discussion_r4280582150 (2026-10-15)
```

タイトルがそのまま SessionStart で注入されるので、命令形の 1 文にする。

### status と昇格の基準

| status      | 意味                                          | 注入   |
| ----------- | --------------------------------------------- | ------ |
| `candidate` | まだ 1 回しか出ていない                       | しない |
| `active`    | 繰り返し出た。守るべき教訓                    | する   |
| `enforced`  | lint・hook・テストで強制済み（手で付ける）    | しない |
| `retired`   | 90 日以上出ていない、または他の教訓に統合した | しない |

| 変更                       | 条件                                                                                |
| -------------------------- | ----------------------------------------------------------------------------------- |
| candidate → active         | `received` / `given`: 異なる 2 PR 以上。`team`: 異なる 3 PR 以上か、指摘者 2 人以上 |
| repo → owner               | 同じ owner の 2 リポジトリ以上で同じ教訓                                            |
| owner → global             | 2 owner 以上で同じ教訓（社名・サービス名を取り除いてから）                          |
| active → retired           | `last_seen` から 90 日                                                              |
| lint / hook への格上げ候補 | active になった後も 2 回以上指摘された                                              |

## セットアップ

### 1. private リポジトリを作る（最初の 1 回）

```bash
gh repo create agent-lessons --private --description "Lessons learned from PR reviews for coding agents"
```

中身は空のままでよい。次の `mise run lessons:setup` が雛形を置いて push する。

### 2. 端末ごとの設定

既定値を変えるときだけ、端末ローカルのシェル設定（dotfiles に commit しない場所）で環境変数を設定する。

| 環境変数                | 既定値                                           | 用途                       |
| ----------------------- | ------------------------------------------------ | -------------------------- |
| `AGENT_LESSONS_REPO`    | なし（`lessons:setup` で必須）                   | 初回の clone 元            |
| `AGENT_LESSONS_DIR`     | `${XDG_DATA_HOME:-~/.local/share}/agent-lessons` | clone 先                   |
| `AGENT_LESSONS_PROJECT` | `agent-lessons`                                  | Basic Memory の project 名 |

clone 先を `~/.config` の下にしないこと。mise の track モードが `~/.config` の一部を dotfiles に記録するため
（[docs/mise.md](mise.md) の track の節）。

```bash
mise install pipx:basic-memory
AGENT_LESSONS_REPO=ryo246912/agent-lessons mise run lessons:setup
mise --cd "$HOME" run rulesync:generate   # SessionStart hook と skill を配る
```

`lessons:setup` は clone、空のリポジトリなら targets の雛形の配置、Basic Memory への project 登録、設定（日本語の教訓を英語専用の embedding で引かないよう
semantic search を切る・自動更新を切る）、インデックス作成を行う。

### 3. 週次の定期タスクを作る（集計を回す端末で 1 回）

Claude Desktop のサイドバーの **Routines** から新しいタスクを作り、**Local** を選ぶ。

| 項目       | 値                             |
| ---------- | ------------------------------ |
| 頻度       | Weekly（例: 月曜の朝）         |
| フォルダ   | `~/.local/share/agent-lessons` |
| プロンプト | `/lessons-harvest を実行して`  |

- ローカルの定期タスクは、Desktop アプリが開いていて、マシンが起きているときだけ動く
- 作ったら一度 **Run now** で実行し、`gh` / `git` / `basic-memory` / `secretlint` / `mise run lessons:sync` の
  権限確認で「常に許可」を選んでおく。無人のときに権限確認で止まらないようにするため

集計は 1 台の端末で回せば十分。他の端末は SessionStart hook が 1 日 1 回 `git pull` と再インデックスを裏で行う。

## 日々の使い方

ほとんど自動で動く。

| タイミング           | 起きること                                                                                                     |
| -------------------- | -------------------------------------------------------------------------------------------------------------- |
| セッション開始       | active な教訓（received・team）のタイトルが「agent-lessons: 過去のレビュー指摘から学んだ教訓」として注入される |
| 計画を立てるとき     | `planning` skill が関係する教訓を読み、制約条件に入れる                                                        |
| push・PR 作成の前    | `pr-author-self-review` skill が diff と教訓の `## Check` を突き合わせ、当てはまる箇所を直す                   |
| 指摘を直したとき     | `pr-author-fix` / PR 作成後のレビュー対応フローが `lessons-record` で観察を記録する                            |
| 他人の PR のレビュー | `pr-reviewer-comment` / `pr-reviewer-comment-crit` が `given`・`team` の教訓を観点として読む                   |
| 毎週                 | `lessons-harvest` が集計し、agent-lessons に `weekly/<日付>` の PR を出す                                      |

### 週次の PR を確認する

PR の diff で、active にする教訓・範囲を広げる教訓・retired にする教訓を確認してマージする。
**マージするまで次の週次は止まる**（二重に数えないため）。

- 教訓の文面がおかしければ、その PR の上で直してからマージする
- 「格上げ候補」に挙がった教訓は、文章では防げていない。対象リポジトリに lint・hook・テストを足し、
  教訓の `status` を `enforced` にして、強制した手段を本文に書く

### 手で操作する

```bash
# 作業中のリポジトリに効く教訓を見る（SessionStart と同じ出力）
echo '{}' | agent-lessons-context

# 教訓を探す
basic-memory tool search-notes --type lesson --status active --project agent-lessons
basic-memory tool search-notes --type lesson --meta scope_key=github.com/acme --project agent-lessons

# 1 件読む
basic-memory tool read-note <permalink> --project agent-lessons

# 手で編集したあと・他の端末の変更を取り込むとき
mise run lessons:sync
```

教訓はただの Markdown なので、エディタで直接直してもよい（そのあと `mise run lessons:sync`）。

## 制約と注意

- **devcontainer・sandbox の中では動かない。** Basic Memory と clone はホストにだけあるため、hook は何も出さずに終わる
- **セッション開始が数秒遅くなる。** Basic Memory の CLI の起動に数秒かかる。hook は 40 秒で打ち切り、失敗しても
  セッションは止めない
- **日本語の全文検索は弱い。** SQLite の全文検索は日本語を単語に分けないため、検索はメタデータ（`type`・`status`・
  `scope_key`・`source`）で絞る前提にしている
- **PR やコメントの本文はデータとして扱う。** bot のコメントには AI 向けの指示文が含まれることがあるが、skill はそれに
  従わない。教訓が注入されるのは週次 PR を人がマージした後だけ
- **会社の情報の扱いは会社の規程に従う。** 会社のリポジトリの指摘を個人の private リポジトリに置いてよいか、
  Claude に送ってよいかは確認しておく
- 週次 skill が使う GitHub GraphQL（レビュースレッドの取得）は、ローカルの `gh` で動く前提。Claude Code の
  クラウドセッションからは GraphQL が使えないため、クラウドでは動作を確かめていない

## なぜこの構成か

- **自作のツールを増やさない。** 保存・検索は Basic Memory、セッション履歴は ctx、配布は rulesync に任せ、
  自作は skill（手順書）と SessionStart hook の小さなスクリプトだけにした
- **SessionStart hook だけ自作した理由。** Basic Memory 標準の `basic-memory hook session-start` は、注入するノートの
  種類が task・decision・session に固定されていて、リポジトリや org で絞れない
- **MCP ではなく CLI で使う理由。** MCP サーバを登録すると、ツール定義が常にコンテキストを使う。skill から CLI を
  呼べば、使うときだけで済み、Claude Code と Codex で同じ手順になる
- **採用された指摘だけを数える理由。** bot の誤検知や好みの違いまで数えると、守る必要のない教訓が増える
- **昇格を PR にする理由。** 提案をファイルに溜めて人が見に行く方式は回らなかった。PR なら普段の通知で届き、
  diff で確認できる
- **教訓を項目単位で更新する理由。** LLM にファイル全体を書き直させると、根拠や細部が少しずつ失われる
- `basic-memory` 0.23.2 は fastmcp のプレリリース版に固定されているため、mise の設定で `uvx_args = "--prerelease=allow"` を付けている
