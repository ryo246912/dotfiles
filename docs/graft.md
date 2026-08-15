# Graft

[Graft](https://github.com/NanoNets/Graft) は、リポジトリのソースコードからローカルなコードグラフを生成し、
Claude Code や Codex がコードの構造・依存関係を少ない探索で把握できるようにする CLI です。
この dotfiles では `@nanonets/graft` を devcontainer 用の mise 設定に固定し、コンテナのビルド時に
`graft` コマンドを導入します。

## 構成

| 項目         | 設定                                                              |
| ------------ | ----------------------------------------------------------------- |
| インストール | `dot_config/devcontainer/mise.toml` の `npm:@nanonets/graft`      |
| 実行場所     | AI エージェントを起動する各プロジェクトの devcontainer 内         |
| 主な連携先   | Claude Code (`claude`) / Codex (`agents`)                         |
| 生成物       | プロジェクト内の `graft/`、エージェントごとの指示・hook・MCP 設定 |

設定反映後は devcontainer を **Rebuild** してください。コンテナ内で次のコマンドが成功すれば
インストール済みです。

```bash
graft --version
```

## プロジェクトへの初期設定

Graft のグラフとエージェント連携はプロジェクト単位です。対象リポジトリのルートで、まず変更予定を
確認してから初期化します。

```bash
cd /path/to/project

# リポジトリ内・ユーザー領域を含む変更予定を表示するだけ
graft init --agents claude agents --dry-run

# Claude Code と Codex を非対話で設定し、初回の構造グラフを生成する
graft init --agents claude agents
```

`claude` は `.claude/skills/graft/SKILL.md`、Claude Code 用 hook・statusline、プロジェクトの
`.mcp.json` を設定します。`agents` は Codex などが読む `AGENTS.md` に Graft の指示を追記します。
さらに devcontainer にはホストの `~/.codex` が bind mount されているため、Codex が検出される場合は
`~/.codex/config.toml` の MCP 登録と `~/.codex/hooks*` の post-edit hook もホスト側へ永続化されます。
既存の設定は Graft 管理の範囲だけが更新され、同じコマンドを再実行できます。

> [!IMPORTANT]
> `agents` のユーザー領域への変更は、同じ `~/.codex` を使うすべてのリポジトリに影響します。
> プロジェクト内の `AGENTS.md` だけを設定したい場合は、初期化と dry-run の両方に
> `--no-global` を追加してください。

初期化後は `git diff` を確認します。Graft が追加した `.claude/`、`.mcp.json`、`AGENTS.md` などの
連携設定はチームで共有できます。一方、再生成可能なグラフは `graft build` が `.gitignore` に追加するため、
通常はコミットしません。既存のプロジェクト方針がある場合は、そちらを優先してください。

非対話環境ではエージェントを明示しない `graft init` は何も書き込みません。devcontainer の terminal や
エージェントから自動化する場合は、上記のように必ず `--agents`（または検出済みの全エージェントを対象にする
`--yes`）を指定します。

## Claude Code / Codex での使い方

初期化後に Claude Code または Codex を**再起動**し、登録された MCP server と指示を読み込ませます。
通常はエージェントが Graft の MCP tools や CLI を必要に応じて使用します。プロンプトでは、例えば次のように
明示できます。

```text
Graftでリポジトリ全体を把握してから、認証処理の変更影響を調べてください。
```

代表的な MCP tool は次のとおりです。

| MCP tool                | 用途                                              |
| ----------------------- | ------------------------------------------------- |
| `graft_repo_map`        | ディレクトリ、主要 symbol、hotspot の全体像を得る |
| `graft_find_code`       | 質問に関連するコードを file/line とともに検索する |
| `graft_file_api`        | ファイル内の signature 一覧を取得する             |
| `graft_trace_calls`     | symbol の呼び出し元・呼び出し先と変更影響を追う   |
| `graft_find_all`        | 正規表現に一致する箇所を symbol 単位で列挙する    |
| `graft_check_freshness` | コード変更に対してグラフが古くないか確認する      |

Claude Code では、これに加えて statusline、プロンプトに関連する context の注入、編集後の変更影響表示と
構造グラフの自動同期が有効になります。Codex では `AGENTS.md` の指示、MCP tools、post-edit hook を通じて
利用します。

## CLI の基本操作

LLM API key がなくても、tree-sitter による構造グラフと次の検索コマンドを利用できます。

```bash
graft build                         # 構造グラフを生成・更新
graft map                           # リポジトリの構成と hotspot を表示
graft ask "認証処理はどこか"       # 質問に関連する node / file / line を表示
graft skeleton src/example.ts       # body を除いた API surface を表示
graft callers authenticate -d 2     # 呼び出し元を2段階追跡
graft callers authenticate --direction out # 呼び出し先を追跡
graft grep "TODO|FIXME"             # indexed file を正規表現検索
graft check                         # drift があれば exit 1
```

`ask`、`map`、`skeleton`、`callers`、`grep` は実行前に変更を検出し、必要な構造グラフを自動更新します。
自動更新を一時的に止める場合は `--no-refresh`、常に止める場合は `GRAFT_NO_REFRESH=1` を使います。

## LLM による deep build（任意）

`graft build --deep` は、構造解析に加えてファイル・symbol の要約や concept node を生成します。この処理だけは
設定した provider の API を呼び出して課金が発生します。通常の自動同期が deep build を勝手に実行することは
ありません。

```bash
# Anthropic の例（値は shell 履歴やリポジトリへ保存しない）
export GRAFT_PROVIDER=anthropic
export GRAFT_API_KEY="..."
export GRAFT_MODEL="<利用するAnthropicのmodel ID>"
graft build --deep
```

OpenAI または OpenAI-compatible endpoint を使う場合は次のように設定します。

```bash
export GRAFT_PROVIDER=openai
export GRAFT_API_KEY="..."
export GRAFT_MODEL="<利用するmodel ID>"
# OpenAI 本体では未設定。OpenRouter / LiteLLM / Ollama などでは指定する
export GRAFT_BASE_URL="https://example.com/v1"
graft build --deep
```

API key は `.env`、mise 設定、dotfiles、devcontainer 定義へ平文でコミットしないでください。必要な場合は
秘密情報管理ツールからコンテナのプロセス環境へ注入します。構造解析だけで十分なら、これらの環境変数は不要です。

## 可視化と devcontainer

グラフをブラウザで確認する場合、コンテナには GUI browser がないため自動起動を無効にします。

```bash
graft viz --port 5000 --no-open
```

現在の Graft viewer はコンテナ内の `127.0.0.1` に bind します。VS Code の port forwarding など、
コンテナ内 loopback を relay できる機能で port `5000` をホストへ転送してアクセスしてください。
Docker の単純な publish は、コンテナの loopback bind へは到達しないため使用できません。複数の
devcontainer を同時に使う場合は、ホスト側 port を固定せず衝突を避けます。

## 更新・再設定・トラブルシュート

```bash
graft version                       # インストール版と公開版を確認
graft init --agents claude agents   # Graft 管理部分を再設定
graft check                         # グラフの drift を確認
graft build                         # グラフを手動再生成
```

- MCP tools が見えない: `graft init --agents claude agents --dry-run` で対象ファイルを確認し、エージェントを
  再起動します。Codex のユーザー設定を避けた場合は `--no-global` の有無も確認します。
- `graft: command not found`: dotfiles を適用して devcontainer を Rebuild し、`mise which graft` を確認します。
- deep build の認証エラー: `GRAFT_PROVIDER`、`GRAFT_API_KEY`、`GRAFT_MODEL` と、互換 API の場合は
  `GRAFT_BASE_URL` を確認します。
- 古い結果が返る: `graft check` の後に `graft build` を実行します。mtime/size ではなく全ファイルを hash して
  判定したい場合は `GRAFT_REFRESH=hash` を設定します。

詳細と最新の対応 agent・option は [Graft の README](https://github.com/NanoNets/Graft#readme) を参照してください。
