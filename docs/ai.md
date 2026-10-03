# AI エージェントの起動コマンド

AI エージェント（Claude Code など）を起動する zabrze snippet（`dot_config/zabrze/ai.toml`）と、
snippet を用意していない起動方法をまとめます。devcontainer の仕組みは
[docs/devcontainer.md](./devcontainer.md) を参照してください。

## ccmanager

| snippet | 展開されるコマンド | 用途 |
| --- | --- | --- |
| `ccm` | `ccmanager` | ホストで起動 |
| `ccmc` | `ccmanager --devc-up-command "devc up" --devc-exec-command "devc exec"` | devcontainer で起動 |
| `ccmcm` | `ccmanager --multi-project --devc-up-command "devc up" --devc-exec-command "devc exec"` | `CCMANAGER_MULTI_PROJECT_ROOT` 配下を横断して devcontainer で起動 |

アカウント（account2 / work3）や resume の有無は、ccmanager の preset
（`dot_config/ccmanager/config.json`）でセッション開始時に選びます。
devcontainer で起動する場合は `(devcontainer, ...)` の付いた preset を選んでください。
ホスト用の preset（`claude2` / `claude-work3`）はホスト側のコマンドなので、コンテナ内にはありません。

## snippet を使わずに起動する

### ホスト

```bash
# work3 用アカウント（初回は ~/.claude-work3 を作成して ~/.claude の設定を共有する）
claude-work3 --dangerously-skip-permissions

# 任意のアカウント
CLAUDE_CONFIG_DIR=~/.claude-account2 claude --dangerously-skip-permissions
```

### devcontainer

`devc exec` の `--` 以降がコンテナ内で実行されます。先に `devc up`（snippet: `dcup`）で起動しておきます。

```bash
# account2 のアカウントで Claude Code を起動（旧 ccmc2 相当）
devc exec -- env CLAUDE_CONFIG_DIR=/home/vscode/.claude-account2 claude --dangerously-skip-permissions

# work3 のアカウントで Claude Code を起動
devc exec -- env CLAUDE_CONFIG_DIR=/home/vscode/.claude-work3 claude --dangerously-skip-permissions
```

`~/.claude-account2` は base template でコンテナへ mount しています。`~/.claude-work3` は
mount していないため、コンテナ内のログイン状態はコンテナを作り直すと消えます。

ccmanager の `--devc-exec-command` は空白で分割され、シェルを通さずに実行されます。
末尾には preset のコマンドが `-- <command>` として追加されるため、`env ...` のような
コマンドは書けません。アカウントを切り替えるときは preset を使ってください。

