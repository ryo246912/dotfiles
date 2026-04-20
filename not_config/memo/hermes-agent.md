# Hermes Agent の使い方と設定メモ

このメモは 2026-04-20 時点で `NousResearch/hermes-agent` の公式ドキュメントと `main` ブランチを確認しながら整理しています。`dotfiles` に入れる前提で、まず動かすところから、`config.yaml` / `.env` / MCP / gateway までをまとめています。

## 先に押さえること

- Hermes Agent は CLI / TUI / messaging gateway を同じ設定ディレクトリ `~/.hermes/` で共有する AI agent です
- 対応環境は Linux / macOS / WSL2 / Android (Termux) です。Windows Native は非対応なので、Windows では WSL2 前提で考えます
- 最初は `hermes` か `hermes --tui` で普通に 1 回会話できる状態を作るのが先です。gateway / cron / MCP / voice はそのあとに足す方が安全です
- 秘密情報は `~/.hermes/.env`、通常設定は `~/.hermes/config.yaml` に分かれています
- 公式 quickstart では 64K 以上の context を持つ model を前提にしています。local model を使う場合は context size を小さくしすぎない方が良いです
- この repo では `dot_hermes/config.yaml` を `~/.hermes/config.yaml` として管理し、API key や token は repo に入れません

## 最短セットアップ

Hermes を最短で動かすなら、まずは installer と provider 設定だけで十分かなと思います。

```sh
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
source ~/.zshrc
```

そのあと、provider を選びます。

```sh
hermes model
```

もしくはまとめて wizard を回すならこちらです。

```sh
hermes setup
```

最低限の確認は以下です。

```sh
hermes
hermes --tui
hermes doctor
hermes status
```

私なら次の順番で進めます。

1. installer を実行する
2. `hermes model` で provider と model を決める
3. `hermes` か `hermes --tui` で 1 回会話する
4. `hermes doctor` で不足を潰す
5. 必要になったら `hermes tools` / `hermes gateway setup` / `hermes mcp add` を足す

## 手動インストール

installer を使わず手で入れたい場合は、公式 docs の manual install に沿って進めます。

```sh
git clone --recurse-submodules https://github.com/NousResearch/hermes-agent.git
cd hermes-agent

curl -LsSf https://astral.sh/uv/install.sh | sh
uv venv venv --python 3.11

export VIRTUAL_ENV="$(pwd)/venv"
uv pip install -e ".[all]"
npm install

mkdir -p ~/.hermes/{cron,sessions,logs,memories,skills,pairing,hooks,image_cache,audio_cache,whatsapp/session}
cp cli-config.yaml.example ~/.hermes/config.yaml
touch ~/.hermes/.env

mkdir -p ~/.local/bin
ln -sf "$(pwd)/venv/bin/hermes" ~/.local/bin/hermes
```

そのあとに provider を設定します。

```sh
hermes model
hermes doctor
```

manual install を使う場面は次かなと思います。

- installer がやっていることを全部把握したいとき
- `.[all]` ではなく extra を自分で絞りたいとき
- repo checkout した Hermes 本体をそのまま開発・追従したいとき

## ディレクトリ構成

Hermes の設定と状態は基本的に `~/.hermes/` の下にまとまります。

```text
~/.hermes/
├── config.yaml
├── .env
├── SOUL.md
├── skills/
├── memories/
├── sessions/
├── logs/
└── state.db
```

主要な役割は以下です。

| パス                    | 役割                                                                      |
| ----------------------- | ------------------------------------------------------------------------- |
| `~/.hermes/config.yaml` | 非秘密の設定。terminal backend、approvals、toolsets、MCP など             |
| `~/.hermes/.env`        | API key や bot token などの秘密情報                                       |
| `~/.hermes/SOUL.md`     | グローバルな personality / tone                                           |
| `~/.hermes/skills/`     | Hermes が読む skill 群。bundled skill、hub skill、agent 作成 skill が入る |
| `~/.hermes/memories/`   | `MEMORY.md` と `USER.md`。session をまたいで残したい情報                  |
| `~/.hermes/sessions/`   | 会話 transcript                                                           |
| `~/.hermes/logs/`       | CLI / gateway / error log                                                 |
| `~/.hermes/state.db`    | session metadata と全文検索用の SQLite                                    |

## 普段よく使うコマンド

日常的に触るコマンドはこのあたりです。

| コマンド                 | 用途                                  |
| ------------------------ | ------------------------------------- |
| `hermes`                 | classic CLI を起動                    |
| `hermes --tui`           | TUI を起動                            |
| `hermes chat -q "..."`   | one-shot 実行                         |
| `hermes --continue`      | 直近 session を再開                   |
| `hermes sessions list`   | session 一覧を見る                    |
| `hermes model`           | provider / model / auth を設定する    |
| `hermes setup`           | 対話 wizard を section ごとに実行する |
| `hermes tools`           | platform ごとの tool 設定を見直す     |
| `hermes status`          | auth / model / platform の状態を見る  |
| `hermes doctor`          | 不足や設定ミスを診断する              |
| `hermes config show`     | 現在の config を確認する              |
| `hermes config edit`     | `config.yaml` を編集する              |
| `hermes config path`     | `config.yaml` の場所を出す            |
| `hermes config env-path` | `.env` の場所を出す                   |
| `hermes config check`    | config の不足や stale 設定を確認する  |
| `hermes config migrate`  | 新しい設定項目を取り込む              |
| `hermes update`          | Hermes 本体を更新する                 |

one-shot の例です。

```sh
hermes chat -q "Summarize this repository in 5 bullets."
hermes chat --toolsets web,terminal,skills -q "Read the repo and propose a release checklist."
hermes chat --continue -q "Continue from the previous investigation."
```

## まず覚えておきたい slash command

CLI と messaging gateway の両方で使えるものを優先して覚えると扱いやすいです。

| slash command     | 役割                                          |
| ----------------- | --------------------------------------------- |
| `/new` / `/reset` | 新しい session を始める                       |
| `/help`           | command 一覧を見る                            |
| `/model`          | 今の session で model を切り替える            |
| `/compress`       | 長くなった context を圧縮する                 |
| `/usage`          | token usage と cost を見る                    |
| `/insights`       | usage analytics を見る                        |
| `/retry`          | 直前の turn をやり直す                        |
| `/undo`           | 直前のやり取りを戻す                          |
| `/skills`         | skill を browse / install する                |
| `/reload-mcp`     | `config.yaml` の MCP 定義を再読込する         |
| `/reload`         | `.env` を session 中に再読込する              |
| `/yolo`           | dangerous command approval を全部 bypass する |

特に気をつけたいのは `hermes model` と `/model` の違いです。

- `hermes model`
  - terminal から実行する
  - provider を追加する
  - OAuth や API key 入力を行う
  - default を保存する
- `/model`
  - session の途中で使う
  - すでに設定済みの provider / model の切り替えだけ
  - 新しい provider の追加や API key 入力はできない

## provider と `.env`

provider を増やしたいときは、基本は `hermes model` が入口です。まず 1 つ provider を安定させてから multi-provider や fallback を触る方がハマりにくいかなと思います。

よく使う `.env` の例です。

```dotenv
# LLM provider
OPENROUTER_API_KEY=sk-or-v1-xxxxx

# Optional tool APIs
FIRECRAWL_API_KEY=fc-xxxxx
TAVILY_API_KEY=tvly-xxxxx
EXA_API_KEY=xxxxx

# Optional Skills Hub / GitHub related
GITHUB_TOKEN=gho_xxxxx
```

`hermes config set` は値の種類に応じて `config.yaml` と `.env` を振り分けてくれるので、手でファイルを開きたくないときに便利です。

```sh
hermes config set OPENROUTER_API_KEY sk-or-v1-xxxxx
hermes config set terminal.backend docker
hermes config set model anthropic/claude-opus-4.6
```

## `config.yaml` の見方

この repo には `dot_hermes/config.yaml` を追加してあります。Hermes の巨大な example config をそのまま持ち込むのではなく、まずはよく触る項目だけを安全側で持つ構成にしています。

### terminal

```yaml
terminal:
  backend: "local"
  cwd: "."
  timeout: 180
```

`terminal.backend` は重要です。

| backend             | 使いどころ                                                 |
| ------------------- | ---------------------------------------------------------- |
| `local`             | ローカルで素早く使うとき。host 上でそのまま command が走る |
| `ssh`               | 別サーバーを実行先にしたいとき                             |
| `docker`            | terminal を container に閉じ込めたいとき                   |
| `singularity`       | HPC などで container backend を使いたいとき                |
| `modal` / `daytona` | cloud sandbox を使いたいとき                               |

安全面の整理としては、`local` は host 上でそのまま実行されるので一番手軽ですが一番強いです。`docker` や `ssh` に逃がすと、安全境界を切りやすくなります。

## approvals

```yaml
approvals:
  mode: "manual"
  timeout: 60
```

`approvals.mode` は次の 3 つです。

| mode     | 挙動                                                        |
| -------- | ----------------------------------------------------------- |
| `manual` | dangerous command のたびに人間確認                          |
| `smart`  | 補助 model で低リスクを自動許可、高リスクは deny / escalate |
| `off`    | すべて auto-approve。`--yolo` 相当                          |

普段使いは `manual` のままで良いと思います。`off` は disposable container や完全自動化の環境以外では使わない方が無難です。

## tools と toolsets

Hermes は tool を個別に持っていますが、普段は `platform_toolsets` で platform ごとにまとめて管理します。

```yaml
platform_toolsets:
  cli: [hermes-cli]
  telegram: [hermes-telegram]
  discord: [hermes-discord]
```

まずは `hermes tools` で対話的に調整する方が楽です。CLI だけ一時的に絞るなら `hermes chat --toolsets terminal,web,file` のような override もできます。

## memory

```yaml
memory:
  memory_enabled: true
  user_profile_enabled: true
  memory_char_limit: 2200
  user_char_limit: 1375
```

Hermes の built-in memory は 2 つに分かれます。

- `MEMORY.md`
  - 環境、規約、作業で学んだこと
- `USER.md`
  - ユーザーの好み、会話スタイル、期待値

どちらも `~/.hermes/memories/` に保存され、session 開始時に prompt に注入されます。session 中に memory を更新しても、prompt の frozen snapshot 自体は次の session まで変わらない点は覚えておくとよいです。

## skills

Hermes の skill は `~/.hermes/skills/` が本体です。主なコマンドはこのあたりです。

```sh
hermes skills browse
hermes skills search react --source skills-sh
hermes skills install official/security/1password
hermes skills list
hermes skills update
hermes skills config
```

`skills.external_dirs` を使うと、ほかの agent 用 skill directory を read-only で参照できます。

```yaml
skills:
  external_dirs:
    - ~/.codex/skills
    - ~/.claude/skills
```

これを使うと、Hermes 専用に skill を重複管理しなくて済むケースがあります。ただし local の `~/.hermes/skills/` が優先されます。

## context files

Hermes は project context file を自動検出します。priority は以下です。

1. `.hermes.md`
2. `AGENTS.md`
3. `CLAUDE.md`
4. `.cursorrules`

加えて `SOUL.md` は常に global personality 用として別枠で読み込まれます。

この repo には root に `CLAUDE.md` があるので、Hermes を repo root で起動すると `CLAUDE.md` を project context として読みます。もし Hermes 専用の指示を分けたいなら `.hermes.md` を追加すると、そちらが優先されます。

subdirectory 側の `AGENTS.md` / `CLAUDE.md` は必要になったタイミングで progressive discovery されるので、monorepo でも使いやすいです。

## MCP の使い方

MCP は external tool server を Hermes にぶら下げる仕組みです。GitHub、filesystem、社内 API などを Hermes の tool として扱えます。

標準 installer なら MCP 対応は入っています。manual install で extra を削った場合だけ `.[mcp]` を追加します。

```sh
cd ~/.hermes/hermes-agent
uv pip install -e ".[mcp]"
```

よく使うコマンドは以下です。

```sh
hermes mcp add filesystem --command npx --args -y @modelcontextprotocol/server-filesystem /Users/ryo./Programming
hermes mcp list
hermes mcp test filesystem
hermes mcp configure filesystem
hermes mcp remove filesystem
```

`config.yaml` に手で書くならこんな形です。

```yaml
mcp_servers:
  filesystem:
    command: "npx"
    args:
      [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/ryo./Programming",
      ]
```

GitHub のように token が必要な server は、repo 管理している `dot_hermes/config.yaml` に実 token を書かない方がよいです。やるなら local の `~/.hermes/config.yaml` にだけ追記するか、private な overlay を使う方が安全です。

変更後は session 中に以下で反映します。

```text
/reload-mcp
```

MCP がつながらないときは次を見ます。

- `node --version` / `npx --version` があるか
- `hermes mcp test <name>` が通るか
- `include` / `exclude` で tool を消していないか
- config 変更後に `/reload-mcp` したか

## gateway と bot 運用

CLI が安定してから `hermes gateway setup` に進むのが基本です。

```sh
hermes gateway setup
hermes gateway status
hermes gateway run
```

platform を常駐させるときの使い分けはこのイメージです。

- macOS / Linux で service 管理したい
  - `hermes gateway install`
  - `hermes gateway start`
- WSL / Docker / Termux
  - `hermes gateway run`

gateway でよく触る `.env` はこのあたりです。

```dotenv
TELEGRAM_BOT_TOKEN=xxxxx
TELEGRAM_ALLOWED_USERS=123456789

DISCORD_BOT_TOKEN=xxxxx
DISCORD_ALLOWED_USERS=111222333444555666

SLACK_BOT_TOKEN=xoxb-xxxxx
SLACK_APP_TOKEN=xapp-xxxxx
SLACK_ALLOWED_USERS=U01ABCDE
```

重要なのは allowlist を空のまま放置しないことです。公式 docs でも、allowlist がない状態では全員 deny になる挙動が明示されています。

## session と profile

Hermes は conversation を session として保存します。再開系はこれだけ覚えておけば十分です。

```sh
hermes --continue
hermes sessions list
hermes sessions browse
```

profile を分けると `config` / `sessions` / `skills` / `home directory` を丸ごと分離できます。

```sh
hermes profile list
hermes profile create work --clone
hermes profile use work
```

仕事用と private 用で provider や gateway を分けたいときに便利です。

## 問題が起きたときの確認順

まずはこの順番で見ると切り分けやすいです。

1. `hermes doctor`
2. `hermes status`
3. `hermes config check`
4. `hermes config migrate`
5. `hermes logs`

よくある症状と見方はこんな感じです。

| 症状                              | 見る場所                                                              |
| --------------------------------- | --------------------------------------------------------------------- |
| `hermes` command が見つからない   | shell を reload したか、`~/.local/bin` が `PATH` に入っているか       |
| provider error / empty reply      | `hermes model` で provider / model / auth をやり直す                  |
| custom endpoint が変              | `OPENAI_BASE_URL` と model 名が本当に OpenAI-compatible か見直す      |
| gateway は動くが bot が応答しない | bot token、allowlist、platform 固有 setup を見直す                    |
| session が出てこない              | `profile` を切り替えていないか、`hermes sessions list` にあるか見る   |
| MCP tool が出ない                 | `hermes mcp test`、`/reload-mcp`、Node.js / server runtime を確認する |
| update 後に設定がずれた           | `hermes config check` と `hermes config migrate` を実行する           |

## `dotfiles` での運用メモ

この repo での扱いは次の整理です。

- `dot_hermes/config.yaml`
  - `~/.hermes/config.yaml` の雛形として管理する
- `~/.hermes/.env`
  - repo に入れず local で管理する
- `not_config/memo/hermes-agent.md`
  - 詳細な使い方の参照先にする
- `setup.md`
  - 最短導線だけ置く

実際には Hermes の example config はかなり大きいので、全部 repo 管理に寄せるより、基本設定だけ `dot_hermes/config.yaml` に置いて、細かい provider token や gateway token は local の `.env` と local override で持つ方がメンテしやすいかなと思います。

特に以下は repo に入れない方が安全です。

- LLM provider の API key
- GitHub / Slack / Discord / Telegram token
- `mcp_servers.*.env` に入れる secret

## 参考リンク

- Installation
  - https://github.com/NousResearch/hermes-agent/blob/main/website/docs/getting-started/installation.md
- Quickstart
  - https://github.com/NousResearch/hermes-agent/blob/main/website/docs/getting-started/quickstart.md
- CLI Commands Reference
  - https://github.com/NousResearch/hermes-agent/blob/main/website/docs/reference/cli-commands.md
- Slash Commands Reference
  - https://github.com/NousResearch/hermes-agent/blob/main/website/docs/reference/slash-commands.md
- Environment Variables Reference
  - https://github.com/NousResearch/hermes-agent/blob/main/website/docs/reference/environment-variables.md
- Security
  - https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/security.md
- Context Files
  - https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/context-files.md
- Skills System
  - https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/skills.md
- Persistent Memory
  - https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/memory.md
- MCP
  - https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/mcp.md
