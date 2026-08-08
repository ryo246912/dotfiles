# agmsg 利用ガイド

`agmsg` は、Claude Code、Codex などの CLI AI エージェントが、ローカルの共有 SQLite DB を介して直接メッセージを交換するためのツールです。常駐デーモンやネットワーク接続を必要とせず、異なるエージェント間で作業依頼、進捗、レビュー結果などを受け渡せます。

## セッションを接続する

Claude Code と Codex を同じプロジェクトで起動し、それぞれ次のコマンドを実行します。

```text
# Claude Code
/agmsg

# Codex
$agmsg
```

初回は両方で**同じチーム名**を選び、重複しないエージェント名（例: `claude` と `codex`）を登録します。以降はエージェントへ自然言語で指示できます。

```text
チームメンバーを確認して
codex に「現在の差分をレビューして、問題点と修正案を返してください」と送って
届いているメッセージを確認して
```

Claude Code ではメッセージがリアルタイムに届きます。Codex は通常、ターンの区切りで受信するため、待機中の Codex には「メッセージを確認して」と新しいターンを与えてください。

## custom skill で作業を引き継ぐ

引き継ぎの作成と受け取りは、Rulesync で Claude Code と Codex に配布する `agmsg-handoff` skill にまとめています。skill は Git の状態と会話から、目的、完了済みの変更、テスト結果、未完了事項、注意点を定型メッセージにまとめ、agmsg で送受信します。

### Claude Code から送る

```text
/agmsg-handoff codex に現在の作業を引き継いで
```

### Codex で受け取り、作業を続ける

```text
$agmsg-handoff claude からの引き継ぎを受け取り、未完了の作業を続けて
```

受信確認だけを行い、まだ実装を始めたくない場合は次のように指定します。

```text
$agmsg-handoff claude からの引き継ぎを確認して。実装はまだ開始しないで
```

受信側は共有 workspace の branch、commit、差分をメッセージと照合します。作業が完了すると、変更ファイル、判断理由、テスト結果、残課題を `[HANDOFF-RESULT]` として送信元へ返します。

## よく使う依頼

### レビューを依頼する

```text
codex に「HEAD の差分をレビューして。特に破壊的変更、セキュリティ、テスト不足を確認し、重要度付きで返信して」と送って
```

### 並行調査を依頼する

```text
codex に「Issue の再現条件だけを調査して。コードは変更せず、再現手順、原因候補、根拠となるファイル位置を返信して」と送って
```

### 状況を問い合わせる

```text
codex に「現在の進捗、完了済み、ブロッカー、次の作業を返信して」と送って
```

### 作業完了を返す

```text
claude に「作業完了。変更: <ファイルと概要>、判断: <理由>、テスト: <コマンドと結果>、残課題: <有無>」と送って
```

## トラブルシュート

### `/agmsg` または `$agmsg` が見つからない

ホスト側で `mise run apm:install` を実行して skill を配布し、Claude Code と Codex を再起動します。devcontainer を先に起動していた場合も、再起動後に skill が読み込まれます。

### `/agmsg-handoff` または `$agmsg-handoff` が見つからない

ホスト側で `chezmoi apply` と `mise run rulesync:generate` を実行して custom skill を再配布し、Claude Code と Codex を再起動します。

### 相手にメッセージが届かない

- 両者でチーム名が一致しているか確認します。
- エージェント名が重複していないか確認します。
- Codex には新しいターンを与えて受信確認を指示します。
- 両者から `~/.agents/skills/agmsg/` が見えることを確認します。

### `sqlite3` のエラーが出る

devcontainer を rebuild し、Dockerfile の依存追加を反映します。
