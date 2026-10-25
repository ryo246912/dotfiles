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
  escalation.md                  # 仕組み化のチェックリスト（lint・hook・テスト・ルールファイルで防ぐ教訓）
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

教訓は最初はすべて指摘を受けたリポジトリの scope_key で作られ、同じ教訓が 2 リポジトリ以上に貯まったものだけが
owner・global へ広がる。そのリポジトリの領域に固有の教訓（地図アプリの座標の順序・タイルの扱いなど）は、一般化できない
からと捨てずにリポジトリの scope_key のまま残し、広げない。SessionStart では、広く効く教訓に押し出されないよう
「このリポジトリ固有の教訓」として別に引いて先に注入する。

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
集め直される）。初回は直近 90 日から集める。

1 回に集める候補は targets ファイルごとに 150 件まで。PR をマージ日の古い順に日単位で処理し、上限に達したら残りの日は
次回に回す（`harvest-state.yml` は処理し切った日の翌日まで進む）。初回や、チームの PR が多いリポジトリで溜まった分は、
週次 PR をマージしたあとに手で `/lessons-harvest` を繰り返せば続きから集まる。

### 教訓（lessons/）の形式

```markdown
---
schema_version: 2
title: 挙動を変えたら旧名称・旧挙動の記述を grep で全件更新する
type: lesson
status: active # candidate / active / ruled / retired
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
since_active: 1 # active になった後に指摘された回数（2 以上で仕組み化の候補）
repos: [github.com/ryo246912/dotfiles] # 根拠のリポジトリ（global に広げてよいかの判定に使う）
globs: ["docs/**", "**/*.example"]
---

## Rule

挙動を変えたら旧名称・旧挙動の記述を grep で全件更新する。

## Patterns

- task 名を変えたが docs の実行例が旧名のまま → 旧名で `git grep` して docs・example も直す
- オプションの既定値を変えたがコメントが旧既定値のまま → 既定値を書いたコメントも同じ commit で直す

## Why

挙動を変えたファイルだけを直し、同じ挙動を説明している別ファイル（docs・example・コメント）を探していなかった。

## Check

diff で消した名前・既定値を `git grep` し、ヒットしたのに diff に無いファイル（docs・example・コメント）。

## Evidence

- https://github.com/ryo246912/dotfiles/pull/1613#discussion_r4280582150 (2026-10-15)
```

タイトルがそのまま SessionStart で注入されるので、命令形の 1 文にする。タイトルと `## Rule` は仕組みの水準で書き
（形の違う同じ指摘も 1 つの教訓で覆う）、実際に指摘された形は `## Patterns` に「ダメな形 → 直し方」で残す。
`## Patterns` は観察が入るたびに `apply_plan.py` が足す（新しい順に 8 件まで）。`## Check` には「〜を確認したか」ではなく、
diff で探すもの（grep する語・コードの形）を書く。ruled にした教訓には、入れた仕組みを書いた `## Mechanism` が
`## Evidence` の前に付く。

`count`・`since_active`・`repos` は観察を足すたびに、
`prs`・`sessions` は `## Evidence` から、team の `reviewers` は `reviewer_hashes` から `apply_plan.py` が更新するので、手で直さない。
`sessions` はセッション ID が残らないため、訂正の日付ごとに 1 と数える（同じ日の訂正をまとめ、早く昇格させないため）。

### status と昇格の基準

| status      | 意味                                                                                                     | 注入   |
| ----------- | -------------------------------------------------------------------------------------------------------- | ------ |
| `candidate` | まだ 1 回しか出ていない                                                                                  | しない |
| `active`    | 繰り返し出た。守るべき教訓                                                                               | する   |
| `ruled`     | 仕組み（lint・hook・テスト・CLAUDE.md などのルールファイル）に移した。`escalation.md` で印を付けると付く | しない |
| `retired`   | 90 日以上出ていない、または他の教訓に統合した                                                            | しない |

| 変更               | 条件                                                                                                               |
| ------------------ | ------------------------------------------------------------------------------------------------------------------ |
| candidate → active | `received` / `given`: 異なる PR と訂正されたセッションの合計が 2 以上。`team`: 異なる 3 PR 以上か、指摘者 2 人以上 |
| repo → owner       | 同じ owner の 2 リポジトリ以上で同じ教訓                                                                           |
| owner → global     | `targets.yml`（個人）のリポジトリだけを根拠に、2 owner 以上で同じ教訓                                              |
| active → retired   | `last_seen` から 90 日                                                                                             |
| 仕組み化の候補     | active になった後も 2 回以上指摘された（モデルが週次で仕組みの案を書いたものも）。`escalation.md` に足される       |

会社など `targets.<name>.yml` のリポジトリが根拠に含まれる教訓は、自動では `global` に広げない（`global` は個人の
リポジトリにも注入されるため）。広げる価値がありそうなものは、固有名詞を取り除いた文面案が週次 PR の「要確認」に載る。

### 形式のバージョン（schema_version）

教訓と観察の frontmatter には、形式のバージョン `schema_version` を入れる（今は `2`。v2 で `## Patterns` を足し、`enforced` を `ruled` に改めた）。今の版は
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
gh repo create agent-lessons --private --description "Lessons learned from PR reviews for coding agents"
```

空のままでよい。最初の `lessons:setup` が `main` に README だけの commit を作って push する（`lessons:sync` と SessionStart
の同期は `main` を前提にしている）。中身は週次の集計と記録で増えていく。

`--add-readme` などで最初から commit がある場合は、既定のブランチが `main` かを確かめ、違えば setup の前に名前を変える
（既定のブランチ名は GitHub アカウントの設定に従う）。

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

`lessons:setup` は clone（空のリポジトリなら最初の commit と push も）、Basic Memory への project 登録、設定（日本語の教訓を英語専用の embedding で引かないよう
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
  コマンド実行と、`~/.local/share/agent-lessons`・`~/.local/state/agent-lessons` へのファイル編集の権限確認で「常に許可」を
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

| タイミング           | 起きること                                                                                                                                                     |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| セッション開始       | active な教訓（received・team）のタイトルが「agent-lessons: 過去のレビュー指摘から学んだ教訓」として注入される（リポジトリ固有 20 件・広く効くもの 30 件まで） |
| 計画を立てるとき     | `planning` skill が関係する教訓を読み、制約条件に入れる                                                                                                        |
| push・PR 作成の前    | `pr-author-self-review` skill が diff と教訓の `## Patterns`・`## Check` を突き合わせ、当てはまる箇所を直す                                                    |
| 指摘を直したとき     | `pr-author-fix` / PR 作成後のレビュー対応フローが `lessons-record` で観察を記録する                                                                            |
| 他人の PR のレビュー | `pr-reviewer-comment` / `pr-reviewer-comment-crit` が `given`・`team` の教訓を観点として読む                                                                   |
| 毎週                 | `lessons-harvest` が集計し、agent-lessons に `weekly/<日付>` の PR を出す                                                                                      |

### 週次の PR を確認する

PR の diff で、active にする教訓・範囲を広げる教訓・retired にする教訓を確認してマージする。
**マージするまで次の週次は止まる**（二重に数えないため）。

- 教訓の文面がおかしければ、その PR の上で直してからマージする
- 「仕組み化のチェックリストに足した教訓」は、注入しても防げていない。下の「仕組み化する」で対応する

### 仕組み化する（escalation.md）

教訓を読ませて守らせるより、lint・hook・テスト・ルールファイルで機械的に防ぐほうが確実。active になった後も指摘され
続ける教訓は、週次の集計が agent-lessons の `escalation.md` の「未対応」に、モデルが書いた仕組みの案付きで足す。

```markdown
## 未対応

- [ ] 読んだ値で更新する処理は、行ロックか条件付き UPDATE で守る — `lessons/team/github.com/o/r/db-row-locking.md`
  - 案: semgrep で WHERE が id だけの UPDATE を検出する。同時に 2 回呼ぶテストを足す
  - 仕組み:

## 済み

- [x] 挙動を変えたら旧名称・旧挙動の記述を grep で全件更新する — `lessons/received/global/doc-behavior-drift.md` (ruled 2026-11-01)
  - 案: …
  - 仕組み: pre-commit で旧名を grep する hook（https://github.com/o/r/pull/12）
```

1. 「未対応」を見て、対象リポジトリに仕組みを入れる（案はたたき台。ほかの方法でもよい）
2. 入れたら `[ ]` を `[x]` にし、`仕組み:` に入れたもの（PR の URL など）を書く。GitHub 上で直接直してもよい
3. `mise run lessons:sync`（週次の段階 0 でも呼ばれる）が、印の付いた教訓を `ruled` にして `## Mechanism` を書き、
   項目を「済み」へ移して commit・push する

ruled の教訓は SessionStart で注入されなくなる。仕組みを入れた後にまた同じ指摘を受けたら、週次 PR の「要確認」に載る
（仕組みが効いていないか、穴がある）。

### 何から教訓を作ったかを確かめる

週次の集計の中間ファイルは、端末ごとに次の場所に残る（commit しない）。

- GitHub から取ったレビュースレッドの生の応答: `~/.cache/agent-lessons/raw/<host>/<owner>/<repo>/<番号>.json`（PR ごと）。
  実行日に関係なく貯まり、集め直すときはここにある PR を GitHub に問い合わせない。対象はマージ済みの PR なので、
  取ったあとに変わることはほとんど無い。取り直したい PR はそのファイルを、全部取り直したいなら `raw/` ごと消す
- それ以外: `~/.local/state/agent-lessons/runs/<実行日>/`

| ファイル                                   | 中身                                                                                 |
| ------------------------------------------ | ------------------------------------------------------------------------------------ |
| `candidates.json`                          | 採用された指摘だけを、source・根拠の URL 付きで、本文を短く削ったもの                |
| `batches/<NNN>.json`                       | モデルに渡した候補（50 件ずつ、判断に要る項目だけ）                                  |
| `observations/<NNN>.json`・`sessions.json` | モデルが一般化して書いた観察（rule・why・check）。`.done` はそのバッチを書き終えた印 |
| `plan.json`                                | 観察をどの教訓に入れたか（attach・create・skip・widen）のモデルの割り当て            |
| `pr-body.md`                               | 週次 PR の本文                                                                       |

流れは `raw` → `candidates.json`（`collect.py` が採用の判定・分類・重複の除外）→ `batches` →
`observations`（モデル）→ `inbox/`（`write_observations.py`）→ `plan.json`（モデル）→ `lessons/`（`apply_plan.py` が
件数・昇格・失効を決める）。教訓の `## Evidence` と観察の `evidence` には元の指摘の URL があり、そこから `raw` や
GitHub のコメントへ辿れる。

### やり直す

直近の週次の結果がおかしいとき（一般化の文面が悪い、割り当てを間違えた、など）は、同じ候補から作り直せる。

先に agent-lessons を集計前に戻すのは、集計の結果（教訓の件数・昇格、観察、`harvest-state.yml` の日付）を取り消すため
（GitHub から集め直すわけではない）。戻さずに作り直すと同じ指摘を二重に数え、さらに `collect.py` は教訓・観察に
根拠の URL がある指摘を「記録済み」として除くので、集め直しても候補に出てこない。

1. agent-lessons を集計前に戻す
   - 週次 PR が未マージなら、PR を閉じてブランチを消す（`git push origin --delete weekly/<実行日>`）。観察も教訓も
     そのブランチにしか無いので、main は集計前のまま
   - マージ済みなら、main でマージ commit を戻して push する（教訓・観察・`harvest-state.yml` がまとめて戻る）

     ```bash
     cd ~/.local/share/agent-lessons
     git revert -m 1 <マージ commit> && git push
     ```

2. `/lessons-harvest redo <実行日>` を実行する。その日の `candidates.json` と `batches/` を使い、GitHub から集め直さずに
   観察と教訓を書き直す

候補から選び直したいとき（採用の判定を変えた、など）は、手順 2 の前にその日の `candidates.json` と `batches/` を
消す。`collect.py` が候補を作り直すが、レビュースレッドは `~/.cache/agent-lessons/raw/` から読み、GitHub には
PR の一覧だけを問い合わせる。

### 手で操作する

```bash
# 作業中のリポジトリに効く教訓を見る（SessionStart と同じ出力）
echo '{}' | agent-lessons-context

# 作業中のリポジトリに効く教訓を、Rule・Patterns・Check 付きで見る（skill と同じ出力）
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
  関係するものだけ読む。常に 40 件を超えるなら、lint などで防げる教訓を `escalation.md` から仕組み化して `ruled` にし、減らす
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
  任せ、メインは段階を呼ぶだけにする。観察を書く段階は候補 50 件ずつに分けて subagent を順に起動し、1 回の
  コンテキストに入る量を一定にする。GitHub からの収集・source の分類・採用の判定・重複の除外（`collect.py`）、観察の
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
