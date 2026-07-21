# crit

[crit](https://github.com/tomasz-tomczyk/crit) は、プラン・diff・フロントエンドをブラウザ上でレビューし、
コメントをそのままエージェントへフィードバックできる CLI ツールです。
**AIエージェントは devcontainer 内で実行する前提**で統合しています（devcontainer 定義は
`dot_config/devcontainer/` を参照）。

## 構成

| 項目         | 設定                                                        | 場所                                                      |
| ------------ | ------------------------------------------------------------ | --------------------------------------------------------- |
| バイナリ     | `github:tomasz-tomczyk/crit` を mise で導入                 | `dot_config/devcontainer/mise.toml`                       |
| バインド先   | `CRIT_HOST=0.0.0.0` / `CRIT_PORT=7842`（コンテナ内は固定）  | `dot_config/devcontainer/devcontainer.json` (`remoteEnv`) |
| ポート公開   | `appPort: 127.0.0.1::7842` でホストへ publish（host port は自動採番） | `dot_config/devcontainer/devcontainer.json`               |
| 自動起動抑止 | `CRIT_NO_UPDATE_CHECK=1`                                    | `dot_config/devcontainer/devcontainer.json`               |
| 動作設定     | `~/.crit.config.json` を生成（`no_open` / `agent_cmd`）     | `dot_config/devcontainer/scripts/post-create.sh`          |
| ポート通知   | 割り当てられた host port を `~/.crit-host-port` に記録し、mac-host へ通知 | `dot_config/devcontainer/scripts/executable_post-start.sh`（適用後: `post-start.sh`） |

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

起動すると（コンテナ内は固定の）`http://0.0.0.0:7842` で待ち受けます。`appPort` によりホストへ
publish されますが、host port は **`127.0.0.1::7842` として Docker に自動採番させている**ため、
devcontainer を複数同時に起動してもポート衝突は起きません。実際に割り当てられた host port は
`~/.crit-host-port` に記録されるので、ホストのブラウザではその番号で `http://localhost:<port>` を
開いてレビュー・コメントします。コメントを送るとエージェントへフィードバックされ、修正ループが回ります。

> [!IMPORTANT]
> ポート公開には **`appPort` を使う**。`forwardPorts` は VS Code 拡張専用で、`multi-worktree` の
> `devcontainer up`（devcontainer CLI）では解釈されず publish されない（これが当初ホストから
> 開けなかった原因）。

## ポートの自動採番と通知

以前は host port を `7842` に固定していたため、devcontainer を同時に2つ以上起動すると
`Bind for 127.0.0.1:7842 failed: port is already allocated` で衝突していた。これを避けるため、
`appPort` の host 側は指定せず(`127.0.0.1::7842`)、Docker に自動採番させている
（`postCreateCommand` / `postStartCommand` が実行される**前**に Docker がポートを確定するため、
コンテナ内のスクリプトから host port 自体を選ぶことはできない）。

自動採番なので、実際に割り当てられた host port はコンテナの外（ホスト側）からしか分からない。
そこで `post-start.sh` が起動のたびに次を行う。

1. コンテナの `$HOSTNAME`（Docker のデフォルトで short container ID と一致）を使い、
   `mac-host` へ SSH して `docker port "$HOSTNAME" 7842/tcp` を実行し、割り当てられた host port を取得
2. 取得できたら `~/.crit-host-port` に書き込む
3. `macos-notify-cli` でホストへ `crit UI: http://localhost:<port>` を通知する

`multi-worktree` に限らず、この base template (`dot_config/devcontainer/devcontainer.json`) から
起動する devcontainer であればどの経路（devcontainer CLI 直接、VS Code など）でも同じ仕組みが働く。
devcontainer 外（`mac-host` に SSH できない環境）では静かにスキップされる。

`/crit` skill（Step 2）は crit 自身が出力する URL をそのまま relay せず、`~/.crit-host-port` が
あればそちらの port を優先して使う（crit が出力するのはコンテナ内固定の `7842` であり、ホストから
実際に開ける port とは異なるため）。

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
