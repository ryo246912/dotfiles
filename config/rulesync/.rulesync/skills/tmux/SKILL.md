---
name: tmux
description: devcontainer からホスト側 tmux pane のログを読み取り、その内容を調査・対応するスキル。`/tmux <pane-id>` または `$tmux <pane-id>` で、別 pane の開発サーバーログやエラーを確認するときに使う。
targets:
  - claudecode
  - codexcli
  - copilot
---

# ホスト側 tmux pane の確認

呼び出し時に指定された pane ID（例: `%3`）を使い、次を実行する。

```bash
host-tmux capture <pane-id>
```

出力を開発サーバーなどの最新ログとして読み取り、エラーの原因、影響、必要な対応を判断する。
ユーザーが修正も求めている場合は、ログに基づいて対象コードを調査・修正し、適切なテストを実行する。

## 手順

1. pane ID が `%` と数字からなることを確認する。
2. pane ID がない、または形式が不正な場合は `host-tmux list` を実行し、候補を示して確認する。
3. `host-tmux capture <pane-id>` を実行する。既定で直近 200 行まで取得される。
4. ログの末尾を優先して分析する。過去に出た解消済みエラーと、現在のエラーを混同しない。
5. 情報が不足する場合だけ、必要な行数を指定して再取得する。

```bash
host-tmux capture <pane-id> 500
```

## 制約

- pane 内容の取得には必ず読み取り専用の `host-tmux` を使う。SSH やホスト側 `tmux` を直接実行しない。
- `send-keys`、`kill-pane`、`respawn-pane` など、ホスト側 tmux の状態を変更する操作は行わない。
- ログに認証情報や秘密情報が含まれる可能性があるため、必要な箇所だけを回答に要約する。
