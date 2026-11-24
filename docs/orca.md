# Orca

[Orca](https://github.com/stablyai/orca) の PC アプリとスマホから、同じ Docker Sandbox 内の
worktree・エージェントセッション・履歴を操作する。Mac の LaunchAgent がアカウントごとの
Orca サーバーを起動する。

| プロファイル | Sandbox         | ポート | Claude の認証    |
| ------------ | --------------- | ------ | ---------------- |
| `oauth`      | `orca-oauth`    | 3840   | sbx OAuth        |
| `account1`   | `orca-account1` | 3841   | subscription kit |
| `account2`   | `orca-account2` | 3842   | subscription kit |
| `work3`      | `orca-work3`    | 3843   | subscription kit |

各プロファイルに sbx と Orca サーバーを一つずつ作る。複数の Git リポジトリや Orca worktree を
同じプロファイルに追加できる。T3 Code を併用するときは、それぞれの UI で作った worktree を使う。

## 初回セットアップ

Docker Sandboxes が使える Mac で実行する。macOS bootstrap は公式 Homebrew tap の
`stablyai/orca/orca` をインストールする。別の PC には
[公式の Orca デスクトップアプリ](https://orca.dev/docs/install)を導入する。
スマホには [公式の Orca Mobile](https://orca.dev/docs/mobile) を導入する。

```sh
mise bootstrap dotfiles diff
mise bootstrap dotfiles apply
mise run bootstrap:mac-packages
mise run sandbox:setup
mise run sandbox:build-template claude
mise run sandbox:claude-token account1
```

`--workspace` には sbx から操作する Git リポジトリ、またはそれだけを置いた親ディレクトリを指定する。
指定したディレクトリの内容は、選択した各 sbx から読み書きできる。
subscription アカウントは使うものだけ token を登録する。

```sh
mise run orca:setup -- --sbx oauth account1 --workspace "$HOME/projects/orca"
```

このタスクは Linux 用 Orca サーバーのアーカイブをホスト側で取得して SHA256 を検証し、
sbx に読み取り専用でマウントする。各サーバーの状態は
`${XDG_DATA_HOME:-$HOME/.local/share}/orca-sandbox/<account>/` に保存する。
同じプロファイルとパスで setup を再実行すると既存の sandbox を再利用する。登録済みの workspace を
変更する場合は LaunchAgent を停止し、必要なデータを退避して sandbox と登録を作り直す。

OAuth 用の Claude は `mise run orca:cli -- --sbx oauth claude` で起動し、必要に応じて
`/login` を実行する。サブスク用の Claude は選んだアカウントの subscription kit を使用する。
Codex は使う sbx ごとに `mise run orca:cli -- --sbx account1 codex login --device-auth` で認証する。
追加の MCP は対象の `orca-<account>` を選んで `mise run sandbox:mcp-load` で割り当てる。

## PC とスマホを接続する

Mac 上の Orca では、接続したいプロファイルのリンクを発行し **Remote Orca Servers → Add Server**
で開く。以下は `account1` の例。

```sh
mise run orca:cli -- --sbx account1 orca pair --address 127.0.0.1
mise run orca:cli -- --sbx account1 orca repo add --path "$HOME/projects/orca/example"
```

Android・iOS は Mac と同じ Tailscale ネットワークに接続する。または同じ LAN を使う。
スマホから Mac の公開ポートに届くことを確認し、下記の IP を Mac の Tailscale IP または LAN IP
に置き換える。別の PC から接続するときも、その PC から届く Mac の IP で PC 用のリンクを発行する。

```sh
mise run orca:cli -- --sbx account1 orca pair --mobile --address 100.64.1.20
```

sbx のポートが Mac の localhost でのみ待ち受けている場合は、Mac で Tailscale Serve の TCP 転送を設定する。
対象のポート番号はアカウントの表に合わせる。

```sh
tailscale serve --bg --tcp=3841 tcp://127.0.0.1:3841
```

Orca Mobile の **Pair** で QR コードを読むか、リンクを開く。
接続できない場合は `sbx ports orca-account1` とホストのファイアウォールを確認する。
公開ポートをルーターからインターネットへ転送しない。ペアリングリンクは接続先の操作権限を与えるため、
接続する端末だけで使う。

デスクトップで登録したプロジェクトと作成した worktree は、同じ接続先のスマホでも表示される。
アカウントを切り替える場合は、PC とスマホで対象の接続先を選ぶ。
最初の作業前に、接続先の `orca-<account>` と worktree を確認する。

### VPN なしで Orca Relay を使う

外出先から VPN なしで接続する場合は、対象 sbx から公式 Relay への TCP 443 を許可する。
次に Orca アカウントでサーバーにログインし、スマホ用の Relay リンクを発行する。
このログインは、sbx 内で使う Claude / Codex の認証とは別に行う。

```sh
sbx policy allow network --sandbox orca-account1 \
  'login.onorca.dev:443,auth.onorca.dev:443,relay.onorca.dev:443,*.relay.onorca.dev:443'
mise run orca:cli -- --sbx account1 orca auth login
mise run orca:cli -- --sbx account1 orca pair --mobile --relay
```

スマホでリンクを開き、求められたら同じ Orca アカウントでログインする。
詳細は [Orca Relay の接続要件](https://orca.dev/docs/mobile#firewalls-and-orca-relay) を参照。

### 自動起動とログ

サーバーは Mac の GUI ログイン時に起動する。Mac がスリープ中は接続できない。
自動起動のログは `${XDG_STATE_HOME:-$HOME/.local/state}/orca-sandbox/<account>.log` にある。
サーバーのみの Linux 版で使える機能とペアリングの詳細は
[Orca の Remote Servers ガイド](https://orca.dev/docs/remote-servers)を参照。
