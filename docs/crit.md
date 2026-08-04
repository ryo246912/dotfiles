# crit

[crit](https://github.com/tomasz-tomczyk/crit) は、プラン・diff・フロントエンドをブラウザ上でレビューし、
コメントをそのままエージェントへフィードバックできる CLI ツールです。
**AIエージェントは devcontainer 内で実行する前提**で統合しています（devcontainer 定義は
`dot_config/devcontainer/` を参照）。

## 構成

| 項目         | 設定                                                                      | 場所                                                                                  |
| ------------ | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| バイナリ     | `github:tomasz-tomczyk/crit` を mise で導入                               | `dot_config/devcontainer/mise.toml`                                                   |
| バインド先   | `CRIT_HOST=0.0.0.0` / `CRIT_PORT=7842`（コンテナ内は固定）                | `dot_config/devcontainer/devcontainer.json` (`remoteEnv`)                             |
| ポート公開   | `appPort: 127.0.0.1::7842` でホストへ publish（host port は自動採番）     | `dot_config/devcontainer/devcontainer.json`                                           |
| 自動起動抑止 | `CRIT_NO_UPDATE_CHECK=1`                                                  | `dot_config/devcontainer/devcontainer.json`                                           |
| 動作設定     | `~/.crit.config.json` を生成（`no_open` / `agent_cmd`）                   | `dot_config/devcontainer/scripts/post-create.sh`                                      |
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

ホストのブラウザで実際に開ける URL の relay は、`crit` ラッパー（後述）が `~/.crit-host-port` を
読んで `crit UI (host): http://localhost:<port>` を追加出力することで行う（crit が出力するのは
コンテナ内固定の `7842` であり、ホストから実際に開ける port とは異なるため）。

## `/crit` skill（APM で upstream 依存として配布）

crit@crit プラグインが提供する 2 つの skill を、**APM の外部依存として upstream から取得**しています。
`dot_apm/apm.yml` の `dependencies.apm` に `tomasz-tomczyk/crit/integrations/claude-code/skills/{crit,crit-cli}`
をコミット SHA 付きで宣言しており、`chezmoi apply` → `mise run apm:install`（= `apm install -g`）で各エージェント
向けに配置されます（`docs/apm.md` 参照）。skill 本文はこのリポジトリに vendor せず、pristine な upstream を使います。

| skill      | 役割                                                               | 配布先                       |
| ---------- | ------------------------------------------------------------------ | ---------------------------- |
| `crit`     | レビューループ（起動 → レビュー → 反映）を自動化する `/crit`       | `~/.claude/skills/crit/`     |
| `crit-cli` | `crit comment` / `share` / `pull` / `push` など CLI のリファレンス | `~/.claude/skills/crit-cli/` |

配置された skill は devcontainer の `~/.claude` マウント経由でコンテナ内のエージェントからも利用できます。

> [!NOTE]
> このリポジトリ固有の devcontainer グルー（host port の URL 差し替え・再レビュー通知）は skill 本文には
> 埋め込まず、`crit` ラッパー（次節）へ分離しています。そのため skill は pristine な upstream をそのまま
> 依存として使えます。

## `crit` ラッパー（devcontainer グルー）

- **host URL の relay**: `~/.crit-host-port` があれば `crit UI (host): http://localhost:<port>` を
  crit 本体の出力とは別に 1 行追加する（crit の出力自体は改変しない）。
- **再レビュー待ち通知**: 既に crit daemon が `:7842` で待ち受けている状態でレビューを起動した
  （＝再レビューラウンド）場合に、`mac-host` へ SSH して `macos-notify-cli` で「再レビュー待ちです」を通知。
  `comments` / `share` / `comment` 等のサブコマンド呼び出しでは通知しない。
