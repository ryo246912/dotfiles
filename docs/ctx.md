# ctx 導入メモ

[ctx](https://github.com/ctxrs/ctx) は、ローカルに保存されている過去の AI coding agent セッション履歴を SQLite に取り込み、現在の agent から高速に検索するための CLI です。

## セットアップ

chezmoi で dotfiles を反映した後、ctx CLI と APM 管理の skills をインストールします。

```bash
chezmoi apply
mise install github:ctxrs/ctx@0.25.0
mise run apm:install
```

`mise run apm:install` は `apm install -g` で生成された `~/.apm/apm.lock.yaml` を chezmoi source directory の `dot_apm/apm.lock.yaml` へコピーします。lockfile どおりに再現インストールする npm ci 相当の task は `mise run apm:ci` です。lockfile だけを反映したい場合は次の task を使います。

```bash
mise run apm:sync-lock
```

初回は ctx のローカル index を作成します。

```bash
ctx setup
```

状態確認は次のコマンドを使います。

```bash
ctx status
ctx sources
```

## よく使うコマンド

自然文で過去セッションを検索します。

```bash
ctx search "failed migration"
```

特定ファイルに関係する過去セッションを探します。

```bash
ctx search --file path/to/file
```

複数キーワードで検索します。

```bash
ctx search --term "failed migration" --term rollback
```

検索結果の event / session ID から詳細を確認します。

```bash
ctx show event <ctx-event-id> --window 3
ctx show session <ctx-session-id>
```

ローカル DB を read-only SQL で確認できます。

```bash
ctx sql "SELECT provider, COUNT(*) AS sessions FROM ctx_sessions GROUP BY provider"
```

ctx 自身のドキュメントも CLI から参照できます。

```bash
ctx docs search "upgrade"
ctx docs show cli-reference
```

## 注意点

- ctx はローカル履歴を扱います。検索結果や `ctx show` の出力を外部へ共有する前に、パス・秘密情報・個人情報が含まれていないか確認してください。
- 公式 installer 管理の binary では `ctx upgrade` が使えますが、この dotfiles では mise と Renovate で version を管理するため、原則として設定ファイルを更新します。
