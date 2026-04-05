# CLAUDE.md

このファイルは `multi-worktree create` が生成する local project 向けガイドです。必要な変更は dotfiles 側の template を更新してください。

## Devcontainer Host Access

- Claude Code から macOS ホストへ任意の shell コマンドを SSH しないでください。
- ホスト通知は `~/.config/devcontainer/scripts/devcontainer-host-action.sh notify --event <pending|stop> [--worktree <safe-name>] [--tmux <0|1>]` だけを使います。
- `.claude/settings.local.json` はこの wrapper を呼ぶ前提で生成されます。raw shell を埋め込む hook に戻さないでください。
- 未定義コマンドや raw shell はホスト側 gateway が拒否し、「確認が必要」であることだけを通知します。
- ホスト側の allowlist や通知文言を変更する場合は、dotfiles 側の gateway・wrapper・この template を合わせて更新してください。
