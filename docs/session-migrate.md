# session-migrate で Claude Code / Codex のセッションを引き継ぐ

[session-migrate](https://github.com/xhluca/session-migrate) は、コーディングエージェントの
ネイティブなセッション履歴を別のエージェントで再開できる形式へ変換する CLI です。
この dotfiles では upstream が現在サポートする Linux（WSL2 を含む）に、mise の `pipx` backend で
`session-migrate` 0.7.1 を導入します。`session-migrate` と短縮名 `smigrate` は同じコマンドです。

> [!IMPORTANT]
> セッション移行は同期ではなく、移行先に新しい独立セッションを作る操作です。移行元は変更されません。
> 認証情報、hooks、MCP、権限・sandbox 設定などの実行環境設定は移行されないため、移行先 CLI は通常の方法で
> あらかじめログイン・設定してください。

## インストール

chezmoi の反映後に Linux 用 mise 設定からインストールします。

```bash
chezmoi apply
mise install
smigrate --version
```

個別に導入し直す場合は次を実行します。

```bash
mise install pipx:session-migrate@0.7.1
```

upstream は Python 3.11 以上および Linux をサポート対象としています。macOS では現時点でこの dotfiles の
自動インストール対象にしていません。

## Claude Code から Codex へ引き継ぐ

移行元セッションへの書き込みが止まってから、そのプロジェクトのディレクトリで実行します。

```bash
cd /path/to/project

# セッションを検索する（UUID が分かっていればこの2行は不要）
smigrate catalog refresh
smigrate catalog search "セッション名のキーワード" --format claude

# まず dry-run。UUID は検索結果の移行元 Claude セッション ID
smigrate transfer CLAUDE_SESSION_UUID --from claude --to codex --cwd "$PWD" --dry-run

# warnings と dropped_events を確認してから移行する
smigrate transfer CLAUDE_SESSION_UUID --from claude --to codex --cwd "$PWD"
```

成功時の JSON に表示された新しい `session_id` を使い、**同じプロジェクトディレクトリ**で再開します。

```bash
codex resume NEW_CODEX_SESSION_UUID
```

## Codex から Claude Code へ引き継ぐ

逆方向も同じ流れです。

```bash
cd /path/to/project

smigrate catalog refresh
smigrate catalog search "セッション名のキーワード" --format codex

smigrate transfer CODEX_SESSION_UUID --from codex --to claude --cwd "$PWD" --dry-run
smigrate transfer CODEX_SESSION_UUID --from codex --to claude --cwd "$PWD"
```

成功時の JSON に表示された新しい `session_id` で Claude Code を再開します。

```bash
claude --resume NEW_CLAUDE_SESSION_UUID
```

## タイトル検索が曖昧な場合

同名セッションや active/archive の重複がある場合は、catalog の不透明な `CATALOG_ID` を指定すると
物理的なセッションを一意に選べます。パスを出力するときは機密情報として扱ってください。

```bash
smigrate catalog refresh
smigrate catalog search "キーワード" --format codex --include-paths
smigrate transfer --catalog-id CATALOG_ID --to claude --cwd "$PWD" --dry-run
smigrate transfer --catalog-id CATALOG_ID --to claude --cwd "$PWD"
```

Claude のプロジェクトパス表現が衝突する場合は、移行元の作業ディレクトリも明示します。

```bash
smigrate transfer CLAUDE_SESSION_UUID --from claude --source-cwd "$PWD" \
  --to codex --cwd "$PWD" --dry-run
```

## 安全に移行するための確認事項

- 最初に必ず `--dry-run` を実行し、出力の `warnings` と `dropped_events` を確認する。
- tool call、画像、compaction summary などは両形式が対応する範囲だけ移行される。private/signed thinking は
  移行されず、モデルや provider のメタデータも移行先の既定値になる。
- `--dry-run` と本実行の間は移行元セッションを更新しない。厳密に同じ移行先 UUID を使いたい場合は、先に
  UUID を生成し、両方のコマンドへ同じ `--session-id NEW_UUID` を渡す。
- 上書き用の `--force` はない。衝突時は新しい UUID を使い、移行先に作成済みの可能性があるというエラーでは
  先に対象 CLI のセッション一覧を確認する。
- manifest や catalog に会話本文は保存されないが、タイトル、パス、作業ディレクトリ、UUID、時刻、hash は
  機密になり得る。会話内の秘密情報は redaction されず、対応するメッセージ等と一緒にコピーされる。
- Codex の paginated/history-base セッションと Claude の sidechain/subagent セッションは移行対象外。
  Claude の sidechain の場合は親セッションを移行する。

構造だけを確認するときは `inspect` が利用できます（会話本文は表示しません）。

```bash
smigrate inspect /path/to/session.jsonl --json
```

全オプションと対応状況は upstream の
[CLI reference](https://github.com/xhluca/session-migrate/blob/main/docs/cli-reference.md)、
[format compatibility](https://github.com/xhluca/session-migrate/blob/main/docs/format-compatibility.md)、
[troubleshooting](https://github.com/xhluca/session-migrate/blob/main/docs/troubleshooting.md) を参照してください。
