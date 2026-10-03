# AI エージェントの起動コマンド

## snippet を使わずに起動する

### ホスト

```bash
# work3 用アカウント（初回は ~/.claude-work3 を作成して ~/.claude の設定を共有する）
claude-work3 --dangerously-skip-permissions

# 任意のアカウント
CLAUDE_CONFIG_DIR=~/.claude-account2 claude --dangerously-skip-permissions
```

### devcontainer

`devcontainer exec` の `--` 以降がコンテナ内で実行されます。先に `dcup` で起動しておきます。
`~/.claude-account2` と `~/.claude-work3` は base template でコンテナへ mount しています。

```bash
# account2 のアカウントで Claude Code を起動
devcontainer exec --workspace-folder . --config ~/.config/devcontainer/devcontainer.json \
  -- env CLAUDE_CONFIG_DIR=/home/vscode/.claude-account2 claude --dangerously-skip-permissions

# work3 のアカウントで Claude Code を起動
devcontainer exec --workspace-folder . --config ~/.config/devcontainer/devcontainer.json \
  -- env CLAUDE_CONFIG_DIR=/home/vscode/.claude-work3 claude --dangerously-skip-permissions
```

multi-worktree の task root では `--config` を省略します（task root に生成された
`.devcontainer/devcontainer.json` が使われます）。
