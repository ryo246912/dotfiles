# crit

[crit](https://github.com/tomasz-tomczyk/crit) は、プラン・diff・フロントエンドをブラウザ上でレビューし、
コメントをそのままエージェントへフィードバックできる CLI ツールです。
**AIエージェントは devcontainer 内で実行する前提**で統合しています（devcontainer 定義は
`dot_config/devcontainer/` を参照）。

## 構成

| 項目         | 設定                                                        | 場所                                                      |
| ------------ | ------------------------------------------------------------ | --------------------------------------------------------- |
| バイナリ     | `github:tomasz-tomczyk/crit` を mise で導入                 | `dot_config/devcontainer/mise.toml`                       |
| バインド先   | `CRIT_HOST=0.0.0.0` / `CRIT_PORT=7842`（デフォルト値）      | `dot_config/devcontainer/devcontainer.json` (`remoteEnv`) |
| ポート公開   | `appPort: 127.0.0.1:7842:7842` でホストへ publish（デフォルト値） | `dot_config/devcontainer/devcontainer.json`               |
| 自動起動抑止 | `CRIT_NO_UPDATE_CHECK=1`                                    | `dot_config/devcontainer/devcontainer.json`               |
| 動作設定     | `~/.crit.config.json` を生成（`no_open` / `agent_cmd`）     | `dot_config/devcontainer/scripts/post-create.sh`          |

`dot_config/devcontainer/devcontainer.json` はベーステンプレートで、`7842` は初期値。
`multi-worktree create` / `recreate` でタスク用の devcontainer.json を生成する際は、
このテンプレートをそのまま使わず、後述のとおり **タスクごとに空いているポートを動的に割り当てる**。

`~/.crit.config.json` の内容:

```json
{
  "no_open": true,
  "agent_cmd": "claude --dangerously-skip-permissions -p"
}
```

- `no_open` … コンテナ内にはブラウザが無いため自動オープンを無効化（UIはホスト側で開く）
- `agent_cmd` … コメントの「Send to agent」で、コンテナ内の `claude` に権限スキップで処理を委譲

## 使い方

コンテナ内でエージェント（または自分）が crit を起動します。

```bash
crit            # git の変更を自動検出してレビュー
crit plan.md    # 特定ファイルをレビュー
```

起動すると `CRIT_PORT`（コンテナ内）で待ち受けます。`appPort` によりホストの同じポート番号へ
publish されるため、ホストのブラウザから `http://localhost:<port>` を開いてレビュー・コメントできます。
コメントを送るとエージェントへフィードバックされ、修正ループが回ります。

> [!IMPORTANT]
> ポート公開には **`appPort` を使う**。`forwardPorts` は VS Code 拡張専用で、`multi-worktree` の
> `devcontainer up`（devcontainer CLI）では解釈されず publish されない（これが当初ホストから
> 開けなかった原因）。

## タスクごとのポート割り当て（衝突回避）

ホストポートを `7842` に固定していると、devcontainer を同時に2つ以上起動したときに
`Bind for 127.0.0.1:7842 failed: port is already allocated` でぶつかる。これを避けるため、
`multi-worktree create` / `recreate`（`generate_devcontainer` 関数）はタスクごとに
**空いているポートを動的に探して割り当てる**。

- `dot_config/devcontainer/devcontainer.json` の `appPort` (`127.0.0.1:7842:7842`) を
  ベースに、`7842` から順に `/dev/tcp/<host>/<port>` で疎通確認しながら空きポートを探索する
  （`find_free_host_port` 関数、`dot_local/bin/executable_multi-worktree`）
- 見つかった port を **host 側・container 側の両方**、および `remoteEnv.CRIT_PORT` に反映する
  （host port と container port を揃えることで、crit が出力する URL がそのままホストから開ける
  ようにしている）
- 生成時に `devcontainer.json を生成しました: ... (crit port: <port>)` とログ表示されるので、
  タスクごとの実際のポートはそこ、または生成された `.devcontainer/devcontainer.json` の
  `appPort` / `remoteEnv.CRIT_PORT` で確認できる
- crit 単体を手動起動する場合（ベーステンプレートをそのまま使う単一コンテナ運用など）は、
  従来どおり `7842` 固定のまま

既存タスクが port 衝突で起動できない場合は、次のコマンドで devcontainer.json を再生成すれば
新しい空きポートが割り当てられる。

```bash
multi-worktree recreate <task-name>
```

## `/crit` skill（rulesync で配布）

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

## 再レビュー待ち通知

1 ラウンド分のレビューコメントにエージェントが対応し終え、次の `crit` 呼び出しで再レビュー待ち
（次の "Finish Review" 待ち）に入る直前、devcontainer からホストへ SSH 経由で通知を送ります。

- 通知コマンド: `ssh -F ~/.config/ssh/config ... mac-host "macos-notify-cli --title 'crit' --message '再レビュー待ちです' ..."`
- 使う SSH 接続は `dot_config/devcontainer/scripts/post-start.sh` が生成する `mac-host`
  （`multi-worktree` のホスト通知と同じ仕組み・同じ鍵 `~/.ssh/id_docker_devcontainer` を利用）
- 手順は `crit` skill（`dot_config/rulesync/exact_dot_rulesync/skills/crit/SKILL.md` の Step 5）に
  記載。`allowed-tools` に `Bash(ssh:*)` を追加してあるため `blockUnlistedCommands` 環境でも実行できる
- devcontainer 外（ホスト上で直接 `crit` を実行した場合など）では `mac-host` に SSH できず失敗するが、
  レビューループを止めないようエラーは無視する
