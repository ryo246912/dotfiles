# devcontainer

AIエージェント（Claude Code / Codex / Copilot など）を隔離環境で実行するための devcontainer 定義です。

- `devcontainer.json` … ベーステンプレート（`multi-worktree` がタスクごとに jq で展開して利用）
- `Dockerfile` … ベースイメージと mise によるツール導入
- `mise.toml` … コンテナ内に導入する CLI ツール一覧
- `scripts/` … `post-create.sh` / `post-start.sh` などの初期化スクリプト

## crit（レビューツール）

[crit](https://github.com/tomasz-tomczyk/crit) は、プラン・diff・フロントエンドをブラウザ上でレビューし、
コメントをそのままエージェントへフィードバックできる CLI ツールです。
**AIエージェントは devcontainer 内で実行する前提**で、以下のように統合しています。

### 構成

| 項目         | 設定                                                    | 場所                              |
| ------------ | ------------------------------------------------------- | --------------------------------- |
| バイナリ     | `github:tomasz-tomczyk/crit` を mise で導入             | `mise.toml`                       |
| バインド先   | `CRIT_HOST=0.0.0.0` / `CRIT_PORT=7842`                  | `devcontainer.json` (`remoteEnv`) |
| ポート公開   | `appPort: 127.0.0.1:7842:7842` でホストへ publish       | `devcontainer.json`               |
| 自動起動抑止 | `CRIT_NO_UPDATE_CHECK=1`                                | `devcontainer.json`               |
| 動作設定     | `~/.crit.config.json` を生成（`no_open` / `agent_cmd`） | `scripts/post-create.sh`          |

`~/.crit.config.json` の内容:

```json
{
  "no_open": true,
  "agent_cmd": "claude --dangerously-skip-permissions -p"
}
```

- `no_open` … コンテナ内にはブラウザが無いため自動オープンを無効化（UIはホスト側で開く）
- `agent_cmd` … コメントの「Send to agent」で、コンテナ内の `claude` に権限スキップで処理を委譲

### 使い方

コンテナ内でエージェント（または自分）が crit を起動します。

```bash
crit            # git の変更を自動検出してレビュー
crit plan.md    # 特定ファイルをレビュー
```

起動すると `http://0.0.0.0:7842` で待ち受けます。`appPort` によりホストの `127.0.0.1:7842` へ
publish されるため、ホストのブラウザから `http://localhost:7842` を開いてレビュー・コメントできます。
コメントを送るとエージェントへフィードバックされ、修正ループが回ります。

> [!IMPORTANT]
> `forwardPorts` は VS Code 拡張専用で、`multi-worktree` の `devcontainer up`（devcontainer CLI）
> では効きません。実際にホストへ publish するのは `appPort` です。
> ホストポート `7842` を固定しているため、**devcontainer を同時に 2 つ以上起動するとポート衝突で
> 2 つ目の `devcontainer up` が失敗**します。crit は 1 度に 1 レビューのため通常は単一コンテナ運用で問題ありません。
> 並列でタスクを回す場合は、対象タスクのコンテナだけを起動してください。

### `/crit` skill（rulesync で配布）

crit@crit プラグインが提供する 2 つの skill を、プラグイン導入ではなく **rulesync 経由で配布**しています。
ソースは `dot_config/rulesync/exact_dot_rulesync/skills/` にあり、`chezmoi apply` 後に
`mise run rulesync:generate` を実行すると各エージェント向けに生成されます。

| skill      | 役割                                                               | 生成先                                                    |
| ---------- | ------------------------------------------------------------------ | --------------------------------------------------------- |
| `crit`     | レビューループ（起動 → レビュー → 反映）を自動化する `/crit`       | `~/.claude/skills/crit/`, `~/.codex/skills/crit/`         |
| `crit-cli` | `crit comment` / `share` / `pull` / `push` など CLI のリファレンス | `~/.claude/skills/crit-cli/`, `~/.codex/skills/crit-cli/` |

生成された skill は devcontainer の `~/.claude` マウント経由でコンテナ内のエージェントからも利用できます。
Claude Code では `/crit`、Codex では `$crit` で呼び出せます。

> [!NOTE]
> `crit` skill は `allowed-tools` に `Bash(crit:*)` を宣言しているため、`blockUnlistedCommands` 環境でも
> skill 実行中は `crit` コマンドが許可されます。`user-invocable` / `argument-hint` は rulesync が
> claudecode skill へ変換する際に落とされますが、動作には影響しません。
