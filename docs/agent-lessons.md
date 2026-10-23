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
| 検索                     | SessionStart は Basic Memory の project `agent-lessons`、skill は `lessons_query.py`     |
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
  harvest-state.yml              # targets ファイルごとの前回の実行日（lessons-harvest が週次 PR の中で更新する）
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

### 収集対象（targets.yml と targets.<name>.yml）

収集するリポジトリは dotfiles の `config/agent-lessons/`（`~/.config/agent-lessons/` に配られる）に書く。
どちらも `lessons-harvest` が読む。

| ファイル             | 書くもの             | git                                                        |
| -------------------- | -------------------- | ---------------------------------------------------------- |
| `targets.yml`        | 個人のリポジトリ     | dotfiles に commit する                                    |
| `targets.<name>.yml` | 会社などのリポジトリ | dotfiles で gitignore（雛形は `targets.work.yml.example`） |

会社の端末では、雛形を `~/.config/agent-lessons/` へコピーし、xxx を実際の値に置き換える。

```bash
cp ~/dotfiles/config/agent-lessons/targets.work.yml.example ~/.config/agent-lessons/targets.work.yml
nvim ~/.config/agent-lessons/targets.work.yml
```

`~/.config/agent-lessons/` は mise の history（`dotfiles-history` への同期を含む）が記録する範囲にあるが、
`targets.*.yml` は `config/mise/config.toml` の `[history] exclude` で記録から外している。

```yaml
repos:
  - repo: github.com/acme/api
    team: true
  - repo: ghe.example.com/platform/infra
    team: true
```

`team: true` のリポジトリでは、自分が関わっていない PR の指摘も集める。前回の実行日は agent-lessons リポジトリの
`harvest-state.yml` にファイル名ごとに持ち、週次 PR がマージされたときだけ進む（PR を閉じれば、その期間はもう一度
集め直される）。

### 教訓（lessons/）の形式

```markdown
---
schema_version: 1
title: 挙動を変えたら旧名称・旧挙動の記述を grep で全件更新する
type: lesson
status: active # candidate / active / enforced / retired
source: received
scope_key: global
category: doc-behavior-drift
count: 4 # 観察の数
prs: 3 # 異なる PR の数
sessions: 0 # ユーザーに訂正された異なるセッションの数
reviewers: 2 # team のときだけ。異なる指摘者の数（名前は残さず reviewer_hashes のハッシュで数える）
first_seen: 2026-10-14
last_seen: 2026-10-16
activated: 2026-10-15 # active になった日
since_active: 1 # active になった後に指摘された回数（2 以上で格上げ候補）
repos: [github.com/ryo246912/dotfiles] # 根拠のリポジトリ（global に広げてよいかの判定に使う）
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

タイトルがそのまま SessionStart で注入されるので、命令形の 1 文にする。`count`・`since_active`・`repos` は観察を足すたびに、
`prs`・`sessions` は `## Evidence` から、team の `reviewers` は `reviewer_hashes` から `apply_plan.py` が更新するので、手で直さない。
`sessions` はセッション ID が残らないため、訂正の日付ごとに 1 と数える（同じ日の訂正をまとめ、早く昇格させないため）。

### status と昇格の基準

| status      | 意味                                          | 注入   |
| ----------- | --------------------------------------------- | ------ |
| `candidate` | まだ 1 回しか出ていない                       | しない |
| `active`    | 繰り返し出た。守るべき教訓                    | する   |
| `enforced`  | lint・hook・テストで強制済み（手で付ける）    | しない |
| `retired`   | 90 日以上出ていない、または他の教訓に統合した | しない |

| 変更                       | 条件                                                                                                               |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| candidate → active         | `received` / `given`: 異なる PR と訂正されたセッションの合計が 2 以上。`team`: 異なる 3 PR 以上か、指摘者 2 人以上 |
| repo → owner               | 同じ owner の 2 リポジトリ以上で同じ教訓                                                                           |
| owner → global             | `targets.yml`（個人）のリポジトリだけを根拠に、2 owner 以上で同じ教訓                                              |
| active → retired           | `last_seen` から 90 日                                                                                             |
| lint / hook への格上げ候補 | active になった後も 2 回以上指摘された                                                                             |

会社など `targets.<name>.yml` のリポジトリが根拠に含まれる教訓は、自動では `global` に広げない（`global` は個人の
リポジトリにも注入されるため）。広げる価値がありそうなものは、固有名詞を取り除いた文面案が週次 PR の「要確認」に載る。

### 形式のバージョン（schema_version）

教訓と観察の frontmatter には、形式のバージョン `schema_version` を入れる（今は `1`）。今の版は
`lessons-harvest/scripts/lessonlib.py` の `SCHEMA_VERSION` で決まり、スクリプトが書くファイルには常にその値が入る。
`schema_version` が無いファイルは、版を付ける前の形式（v0）として扱う。

| 状況                            | 動き                                                                                                            |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| 古い版のファイルがある          | 書き込むスクリプト（`write_observations.py`・`apply_plan.py`）は止まる。`lessons_query.py` は警告だけ出して読む |
| 新しい版のファイルがある        | どのスクリプトも止まる。その端末の dotfiles が古いので、更新して rulesync で skill を配り直す                   |
| 週次の集計（`lessons-harvest`） | 段階 0 で `migrate.py` が古い版を今の版まで移行し、週次 PR とは別に main へ push する                           |

形式を変えるときは、次の 3 つを同じ PR で行う。

1. `lessonlib.py` の `SCHEMA_VERSION` を 1 上げる
2. `migrate.py` の `MIGRATIONS` に「前の版 → 今の版」の関数を足す（frontmatter と本文を受け取り、直したものを返す）。
   古いファイルは版の順に移行される（v0 → v1 → v2 …）。何度実行しても結果は変わらないように書く
3. 書き込むスクリプトと `lessons-record` skill の雛形（`schema_version` を含む）を新しい形式にする

手で移行するときは次のとおり。

```bash
python3 ~/.claude/skills/lessons-harvest/scripts/migrate.py --check   # 版ごとの件数。移行が要るなら終了コード 1
python3 ~/.claude/skills/lessons-harvest/scripts/migrate.py           # 今の版まで移行する
mise run lessons:sync
```

## セットアップ

### 1. private リポジトリを作る（最初の 1 回）

```bash
gh repo create agent-lessons --private --add-readme --description "Lessons learned from PR reviews for coding agents"
```

README だけでよい（`main` ブランチを作るため）。中身は週次の集計と記録で増えていく。

既定のブランチ名は GitHub アカウントの設定に従う。`main` でなければ（`lessons:sync` と SessionStart の同期は `main` を前提に
している）、setup の前に名前を変える。

```bash
gh repo view ryo246912/agent-lessons --json defaultBranchRef --jq .defaultBranchRef.name
gh api -X POST repos/ryo246912/agent-lessons/branches/<今の名前>/rename -f new_name=main   # main でなければ
```

### 2. 端末ごとの設定

clone 先は `~/.local/share/agent-lessons`、リポジトリは `ryo246912/agent-lessons`、Basic Memory の project 名は
`agent-lessons` で固定している。clone 先を `~/.config` の下にしないのは、mise の track モードが `~/.config` の一部を
dotfiles に記録するため（[docs/mise.md](mise.md) の track の節）。

```bash
mise install pipx:basic-memory
mise run lessons:setup
mise --cd "$HOME" run rulesync:generate   # SessionStart hook と skill を配る
```

`lessons:setup` は clone、Basic Memory への project 登録、設定（日本語の教訓を英語専用の embedding で引かないよう
semantic search を切る・自動更新を切る）、インデックス作成を行う。この 2 つの設定は Basic Memory 全体に効くため、
Basic Memory を他の用途でも使っていて semantic search が要るなら、`lessons:setup` のあとで戻す。

### 3. 週次の定期タスクを作る（集計を回す端末で 1 回）

Claude Desktop のサイドバーの **Routines** から新しいタスクを作り、**Local** を選ぶ。

| 項目         | 値                             |
| ------------ | ------------------------------ |
| Schedule     | Weekly（例: 月曜 9:00）        |
| 権限モード   | Manual                         |
| フォルダ     | `~/.local/share/agent-lessons` |
| Instructions | `/lessons-harvest を実行して`  |

- 作ったら一度 **Run now** で実行し、`gh` / `git` / `python3` / `basic-memory` / `secretlint` / `mise run lessons:sync` の
  コマンド実行と、`~/.local/share/agent-lessons`・`~/.cache/agent-lessons` へのファイル編集の権限確認で「常に許可」を
  選んでおく。以後の週次実行は同じ操作なら確認なしで通り、許可していない操作が出たときだけ止まって承認を待つ
  （サイドバーの **Scheduled** に残る）
- 権限モードを Auto にしないのは、分類器がセッション履歴から作った要約の commit・push を止めることがあり、
  3 回続けて止まると確認待ちになって、無人の実行がいつ止まるか読めないため
- 1 時間おきなど細かくしないのは、集めるのがマージ済みの PR だけで新しい指摘がほとんど無く、前回の週次 PR が
  未マージなら何もせずに終わるため（それでも毎回セッションが起動してトークンを使う）
- ローカルの定期タスクは、Desktop アプリが開いていてマシンが起きているときだけ動く。予定の時刻に寝ていた回は
  スキップされ、起動や復帰のときに過去 7 日以内に逃した直近の 1 回だけを実行する。夜間や休日を気にする必要はない

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

# 作業中のリポジトリに効く教訓を、Rule と Check 付きで見る（skill と同じ出力）
# Claude Code の skill は ~/.claude/skills、Codex は ~/.agents/skills に配られる（どちらも同じスクリプト）
python3 ~/.claude/skills/lessons-harvest/scripts/lessons_query.py --full

# 全教訓の一覧（status を問わない）
python3 ~/.claude/skills/lessons-harvest/scripts/lessons_query.py --index

# 手で編集したあと・他の端末の変更を取り込むとき
mise run lessons:sync
```

教訓はただの Markdown なので、エディタで直接直してもよい（そのあと `mise run lessons:sync`）。

## 制約と注意

- **devcontainer・sandbox の中では動かない。** Basic Memory と clone はホストにだけあるため、hook は何も出さずに終わる
- **セッション開始が数秒遅くなる。** Basic Memory の CLI の起動に数秒かかる。hook は 40 秒で打ち切り、失敗しても
  セッションは止めない
- **注入する教訓は 40 件まで。** コンテキストを抑えるため。超えた分は push 前の `pr-author-self-review` が diff に
  関係するものだけ読む。常に 40 件を超えるなら、lint などで強制できる教訓を `enforced` にして減らす
- **日本語の全文検索は弱い。** SQLite の全文検索は日本語を単語に分けないため、検索はメタデータ（`type`・`status`・
  `scope_key`・`source`）で絞る前提にしている
- **PR やコメントの本文はデータとして扱う。** bot のコメントには AI 向けの指示文が含まれることがあるが、skill はそれに
  従わない。教訓が注入されるのは週次 PR を人がマージした後だけ
- **会社の情報の扱いは会社の規程に従う。** 会社のリポジトリの指摘を個人の private リポジトリに置いてよいか、
  Claude に送ってよいかは確認しておく
- 週次 skill が使う GitHub GraphQL（レビュースレッドの取得）は、ローカルの `gh` で動く前提。Claude Code の
  クラウドセッションからは GraphQL が使えないため、クラウドでは動作を確かめていない

## なぜこの構成か

- **自作のツールを増やさない。** 保存は git と Basic Memory、セッション履歴は ctx、配布は rulesync に任せ、
  自作は skill（手順書と、skill に同梱するスクリプト）と SessionStart hook の小さなスクリプトだけにした
- **SessionStart hook だけ自作した理由。** Basic Memory 標準の `basic-memory hook session-start` は、注入するノートの
  種類が task・decision・session に固定されていて、リポジトリや org で絞れない
- **MCP ではなく CLI で使う理由。** MCP サーバを登録すると、ツール定義が常にコンテキストを使う。skill から CLI を
  呼べば、使うときだけで済み、Claude Code と Codex で同じ手順になる
- **採用された指摘だけを数える理由。** bot の誤検知や好みの違いまで数えると、守る必要のない教訓が増える
- **トークンを抑える作り。** `pr-reviewer-brief` と同じく、週次の集計を段階に分けて `haiku` / `sonnet` の subagent に
  任せ、メインは段階を呼ぶだけにする。GitHub からの収集・source の分類・採用の判定・重複の除外（`collect.py`）、観察の
  書き出し（`write_observations.py`）、件数の集計・昇格・失効の判定（`apply_plan.py`）はスクリプトが行い、モデルは
  一般化した文章と、観察をどの教訓に入れるかの割り当てだけを JSON で書く。GitHub の生の応答や bot の定型文
  （折りたたみ・HTML・AI 向けの指示文）はスクリプトで落としてからモデルに渡す
- **skill は教訓を 1 回で引く。** `pr-author-self-review`・`planning`・`pr-reviewer-comment` は `lessons_query.py` で、
  scope・source・変更ファイルの glob に合う教訓だけを Rule・Check 付きで 1 回で出す（Basic Memory で 1 件ずつ
  read-note しない）。SessionStart で注入するのも教訓のタイトルだけにしている
- **昇格を PR にする理由。** 提案をファイルに溜めて人が見に行く方式は回らなかった。PR なら普段の通知で届き、
  diff で確認できる
- **教訓を項目単位で更新する理由。** LLM にファイル全体を書き直させると、根拠や細部が少しずつ失われる
- `basic-memory` 0.23.2 は fastmcp のプレリリース版に固定されているため、mise の設定で `uvx_args = "--prerelease=allow"` を付けている
