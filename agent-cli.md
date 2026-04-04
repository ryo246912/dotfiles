# Agent CLI ガイド

2026-04-05 時点で、ticket `DOTFILE-24` の条件に合わせて「agent CLI のみ」「公式 repo が直近 1 か月以内に更新されているもの」の設定を整理したガイドです。

## スコープ

| Tool | 判定 | 公式 repo 更新日 | install backend | repo 管理する設定 | 無料利用メモ | 学習利用メモ |
| --- | --- | --- | --- | --- | --- | --- |
| [aider](https://github.com/Aider-AI/aider) | 対象 | 2026-03-17 | `pipx:aider-chat` | `~/.aider.conf.yml` | CLI 本体は無料。実利用コストは接続先 provider 依存 | aider の analytics は opt-in。モデル入力の学習可否は provider 依存 |
| [cline](https://github.com/cline/cline) | 対象 | 2026-04-04 | `npm:cline` | `~/.cline/` | Cline Provider に free model あり。BYOK / local も可 | BYOK ではコードは Cline サーバーを通らない。学習可否は provider / local 設定依存 |
| [codebuff](https://github.com/CodebuffAI/codebuff) | 対象 | 2026-04-03 | `npm:codebuff` | `~/.config/manicode/` | `codebuff` は有償前提。無料優先なら sister CLI の `freebuff` を使う | chat 履歴のローカル保存は確認できるが、no-training の公式明示は未確認 |
| [crush](https://github.com/charmbracelet/crush) | 対象 | 2026-04-04 | `npm:@charmland/crush` | `~/.config/crush/crush.json` | CLI 本体は無料。provider API / subscription は別 | `disable_metrics=true` を既定化。モデル入力の学習可否は provider 依存 |
| [gemini-cli](https://github.com/google-gemini/gemini-cli) | 対象 | 2026-04-04 | `npm:@google/gemini-cli` | `~/.gemini/settings.json` | 個人 Google account で free tier あり | `usageStatisticsEnabled=false` にしても、学習可否は Google 側の privacy notice を確認する前提 |
| [goose](https://github.com/block/goose) | 対象 | 2026-04-04 | `github:block/goose` | `~/.config/goose/config.yaml` | CLI 本体は無料。provider は local / BYOK を選べる | `GOOSE_TELEMETRY_ENABLED=false` を既定化。モデル入力の学習可否は provider 依存 |
| [gptme](https://github.com/gptme/gptme) | 対象 | 2026-04-04 | `pipx:gptme` | `~/.config/gptme/config.toml` | CLI 本体は無料。local / BYOK 前提で使いやすい | no-training の公式明示は未確認。local ならローカル完結、cloud は provider 依存 |
| [nanocoder](https://github.com/Nano-Collective/nanocoder) | 対象 | 2026-04-04 | `npm:@nanocollective/nanocoder` | `~/.config/nanocoder/agents.config.json` | CLI 本体は無料。local / GitHub Models / OpenRouter などを選べる | local-first 方針。学習可否は接続先 provider 依存 |
| [neovate](https://github.com/neovateai/neovate-code) | 対象 | 2026-03-24 | `npm:@neovate/code` | `~/.neovate/` | CLI 本体は無料だが、実運用は provider API key 前提寄り | no-training の公式明示は未確認。provider 依存として扱う |
| [qwen-code](https://github.com/QwenLM/qwen-code) | 対象 | 2026-04-04 | `npm:@qwen-code/qwen-code` | `~/.qwen/settings.json` | Qwen OAuth で 1,000 requests/day の free tier あり | `usageStatisticsEnabled=false` を既定化。学習可否は Qwen / Alibaba 側 terms 依存 |
| [opencode](https://github.com/opencode-ai/opencode) | 除外 | 2025-09-18 | 追加なし | 既存 legacy config のみ | archive 済み | 「直近 1 か月コミットあり」の条件外 |

## この repo で追加したもの

- host / devcontainer の `mise` から対象 CLI を入れられるようにした
- devcontainer に agent CLI の config / data directory mount を追加した
- `zabrze` と `multi-worktree` に起動ショートカットを追加した
- 静的 config を安全に持てるツールだけ repo 管理の初期設定を追加した
  - aider
  - crush
  - goose
  - gptme
  - nanocoder
  - qwen-code
- `cline` / `codebuff` / `neovate` は static config が弱いので、install / mount / docs 中心で整理した

## セットアップ

### 1. install

```sh
mise install --jobs=2
```

### 2. bootstrap

```sh
setup-ai-tool
```

この script は以下を行います。

- 各 agent CLI 用ディレクトリの事前作成
- Claude MCP (`deepwiki`, `modular-mcp`) の再登録
- `neovate` が入っていれば auto-update 無効化

### 3. host で直接起動

```sh
aider
cline
codebuff
crush
gemini
goose
gptme
nanocoder
neovate
qwen
```

### 4. devcontainer 経由で起動

`zabrze` を使う前提なら、以下の trigger を追加してあります。

| Tool | Trigger |
| --- | --- |
| aider | `ccmad` |
| cline | `ccmcl` |
| codebuff | `ccmcb` |
| crush | `ccmcr` |
| gemini | `ccmcg` |
| goose | `ccmgo` |
| gptme | `ccmgm` |
| nanocoder | `ccmnc` |
| neovate | `ccmnv` |
| qwen | `ccmqw` |

`multi-worktree` を使う場合は `multi-worktree dev <tool>` でも呼べるように sample を更新してあります。

## 管理している設定ファイル

| Tool | Path | 意図 |
| --- | --- | --- |
| aider | `~/.aider.conf.yml` | auto commit を切り、repo map / notifications / history を有効にする |
| crush | `~/.config/crush/crush.json` | metrics 無効化、compact UI、`AGENTS.md` 初期化、context file 優先 |
| goose | `~/.config/goose/config.yaml` | telemetry 無効化、`smart_approve`、theme / compaction の既定値 |
| gptme | `~/.config/gptme/config.toml` | MCP 自動起動、chat history / cost 表示、応答スタイル |
| nanocoder | `~/.config/nanocoder/agents.config.json` | provider 雛形、session 保存、auto compact、safe tool の auto allow |
| qwen-code | `~/.qwen/settings.json` | usage stats 無効化、session retention、safe tool auto-accept |

## ツール別メモ

### aider

- `.aider.conf.yml` は model を固定していない。無料寄りで使うなら `GEMINI_API_KEY` や local provider を別途選ぶ。
- analytics は opt-in なので、CLI 側で勝手にコードを送る前提にはしない。

### cline

- repo では `~/.cline/` ディレクトリだけ用意している。
- 初回設定は `cline config` で行うのが正道。
- privacy を優先するなら BYOK か local model を使う。

### codebuff

- `codebuff` 自体は対象に入れているが、無料優先なら `freebuff` のほうが目的に合う。
- project ごとの `knowledge.md` と `.agents/` は CLI 内の `/init` で生成する前提。

### crush

- provider は config に固定していない。`GEMINI_API_KEY` / `OPENROUTER_API_KEY` / `ANTHROPIC_API_KEY` など、使うものだけ環境変数で渡す。
- `~/.config/crush/skills/` は後から custom skill を追加できるように空ディレクトリだけ持たせている。

### gemini-cli

- 既存の `~/.gemini/settings.json` を引き続き使う。
- 無料重視なら personal Google account OAuth が最短。
- no-training を最優先にするなら、個人 OAuth ではなく契約と privacy 条件が明確な provider に切り替える。

### goose

- `config.yaml` では telemetry を切っている。
- API key は `secrets.yaml` か keyring 側に逃がす前提で、repo に secret は置かない。

### gptme

- global config と project config が分かれている。
- repo 管理するのは `~/.config/gptme/config.toml` だけで、秘密情報は `config.local.toml` に分離する前提。

### nanocoder

- `agents.config.json` に local / GitHub Models / Gemini API の雛形を入れている。
- 実 key は環境変数参照 (`$GITHUB_TOKEN`, `$GEMINI_API_KEY`) にしている。

### neovate

- docs から `~/.neovate/` 配下に request log / session log が置かれることを確認している。
- `setup-ai-tool` で `neovate config set autoUpdate false -g` を試す。

### qwen-code

- 無料重視なら Qwen OAuth を使う。
- `settings.json` では auth type を固定していないので、初回は `qwen` 起動後に `/auth` を使う。

## 無料 / privacy を優先するなら

- いちばん free で始めやすい:
  - `gemini`
  - `qwen`
  - `cline` の free models
- いちばん no-training に寄せやすい:
  - `aider`
  - `cline`
  - `goose`
  - `gptme`
  - `nanocoder`

上の「no-training に寄せやすい」は、CLI ではなく接続先を local model / BYOK provider に寄せやすいという意味です。CLI が OSS でも、cloud provider に送れば学習可否は provider 契約に依存します。

## 参考リンク

- aider: <https://aider.chat/docs/> / <https://aider.chat/docs/more/analytics.html>
- cline: <https://docs.cline.bot/cline-cli/configuration> / <https://docs.cline.bot/getting-started/authorizing-with-cline> / <https://cline.bot/get-cline>
- codebuff: <https://github.com/CodebuffAI/codebuff> / <https://www.codebuff.com/docs/advanced>
- crush: <https://github.com/charmbracelet/crush>
- gemini-cli: <https://github.com/google-gemini/gemini-cli> / <https://developers.google.com/gemini-code-assist/resources/faqs>
- goose: <https://github.com/block/goose> / <https://block.github.io/goose/docs/guides/config-files/>
- gptme: <https://github.com/gptme/gptme> / <https://gptme.org/docs/index.html> / <https://gptme.org/docs/config.html>
- nanocoder: <https://github.com/Nano-Collective/nanocoder> / <https://docs.nanocollective.org/nanocoder/docs/configuration/>
- neovate: <https://github.com/neovateai/neovate-code> / <https://neovateai.dev/docs/installation> / <https://neovateai.dev/docs/troubleshooting>
- qwen-code: <https://github.com/QwenLM/qwen-code> / <https://qwenlm.github.io/qwen-code-docs/en/users/overview/>
