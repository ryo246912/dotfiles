# T3 Code — 普段はアプリだけで操作する

初回だけターミナルでアカウントと接続を設定する。以降は T3 Code アプリから
新規セッション・再開・実装・差分確認・コミット・PR 作成まで操作する。

- **アカウントごとに常駐 sbx を一つ**用意し、その中で T3 サーバーとエージェントを動かす。
- **worktree はセッションごと**に T3 が作成する。同じアカウントのセッションは sbx を共有する。
- デスクトップもスマホも同じサーバーに接続するので、同じセッションと履歴を見られる。
- 日常の操作で `mise run t3:run` やターミナルの常駐は必要ない。

## 初回導入

Docker Sandboxes の `sbx` が利用できる PC が必要。通常の Docker Engine だけでは足りない。
ホストの Python 3.9 以上、mise、Git、T3 Code デスクトップアプリも必要。
`npm:t3` はホストと sandbox の mise 設定で **0.1.10** に固定している。
初回実行時に公式の実行ファイルを取得し、SHA256SUMS で確認する。

```bash
cd /path/to/dotfiles
mise bootstrap dotfiles apply
mise install
mise run sandbox:setup
mise run sandbox:build-template claude
```

template は T3 追加後に再ビルドする。作成済みの sandbox は更新されないので、この構成では
専用の `t3-account1` / `t3-account2` / `t3-work3` を作る。他用途の sandbox は再利用・削除しない。
T3 アプリは [公式ダウンロード](https://t3.codes/download) から導入する。
macOS のアプリも mise の `[bootstrap.packages]` で管理する。
`mise bootstrap packages apply brew-cask:t3-code` で導入できる。
Homebrew の公開版がサーバーより古い場合は、アプリも公式リリースの対応する版へ更新する。

## 最初にアカウントを選ぶ

初回だけ、最初に登録する Git リポジトリで次を実行する。

```bash
cd /path/to/project
mise run t3:setup
```

`account1`・`account2`・`work3` の選択メニューが出る。これは既存の Claude サブスク用
アカウント名で、T3 Connect のログイン名とは別。

| 選択     | Claude 設定          | 専用 sbx      | PC 側の接続先           |
| -------- | -------------------- | ------------- | ----------------------- |
| account1 | `~/.claude`          | `t3-account1` | `http://127.0.0.1:3773` |
| account2 | `~/.claude-account2` | `t3-account2` | `http://127.0.0.1:3774` |
| work3    | `~/.claude-work3`    | `t3-work3`    | `http://127.0.0.1:3775` |

選んだアカウントの `sbx-agent --claude-account` と subscription kit を使い、
Claude の認証先をその sandbox に固定する。token が未登録の場合は停止する。

```bash
mise run sandbox:claude-token account2
# メニューを使わず指定する場合
mise run t3:setup -- --account account2 --workspace /path/to/project
```

`sandbox:setup` が行う認証 binding も必要。詳細は [Docker Sandboxes](docker-sandboxes.md) を参照。
Codex など他の provider の認証は sandbox 内の T3 Providers 設定で別途行う。
このアカウント選択が切り替えるのは Claude の subscription 認証。

setup は sandbox を準備し、新規セッションの既定値として `defaultThreadEnvMode: "worktree"`
を設定する。既存の T3 設定は上書きしない。macOS では LaunchAgent、Linux では systemd user
service を登録して T3 をバックグラウンドで起動する。同じ設定で setup を再実行しても、
実行中のサービスを再起動しない。

## デスクトップアプリを最初に接続する

1. ホストの T3 Code アプリを開く。
2. Settings → Environments で **Local environment をオフ**にし、アプリをリモート操作用にする。
3. 初回だけ `mise run t3:cli -- account2 pair` を実行する（選択したアカウントに置換）。
4. Add environment に表の **PC 側の接続先**とペアリングコードを入力する。
   sandbox 内で生成された URL の IP ではなく、`http://127.0.0.1:3774` などを使う。
5. 必要なら表示名を `account2` などに変更し、Providers で Claude の認証状態を確認する。

サービス起動直後に pair が「サーバーがない」と返す場合は、起動完了後に再実行する。
ペアリングは端末ごとに一度だけでよい。URL / コードは認証情報なのでコミット・共有しない。
複数アカウントを使う場合は、それぞれ一度 setup と接続を行う。
**以降のアカウント切替はアプリの接続先環境を選ぶだけ**。

## 普段の操作

1. T3 Code アプリを開き、作業するアカウントの環境を選ぶ。
2. プロジェクトを選び、新規スレッドを作る。実装時の作業先が **New worktree** か確認する。
3. アプリから依頼し、実装・確認・コミット・PR 作成を行う。
4. 再開はアプリの既存スレッドを選ぶ。

T3 サーバーも provider も terminal も sbx 内で動く。ホストの Local environment を
再びオンにした場合、その環境での作業はこの構成を経由しない。
プロジェクト単位で local を指定すると worktree の既定値よりそちらが優先される。
新規作成した空のプロジェクトの最初のスレッドなど、T3 が元フォルダを使う例外もあるため、
実装前に作業先表示を確認する。worktree 作成には開始コミットが必要。

追加プロジェクトはアプリの Add Project で clone できる。T3 データ領域内の projects など、
sandbox に渡したディレクトリへ保存する。ホストの任意の別ディレクトリは見えない。

## スマホから接続する（初回のみ）

iOS / Android の公式アプリ、または https://app.t3.codes を使う。
PC のアプリで対象アカウントの環境を選び、Settings → Sharing & access から
**T3 Connect** を有効化して本人認証する。スマホで同じ T3 Connect アカウントにログインし、
対象環境を選ぶと同じセッションを開ける。必要に応じて新規デバイス承認を有効にする。
標準上限は 3 環境なので、3 アカウントを公開すると 3 台分になる。

sbx のネットワーク制限で Connect / Cloudflare tunnel が動かない場合は、
`sbx policy log` で必要な通信先を確認するか、ホスト側の Tailscale を使う。
PC とスマホを同じ tailnet に接続し、MagicDNS と HTTPS 証明書を有効化して初回のみ:

```bash
# account2 の例。HTTPS port はアカウントごとに分ける。
tailscale serve --bg --https=8443 http://127.0.0.1:3774
mise run t3:cli -- account2 pair
```

スマホの Add environment に `https://<PCのMagicDNS名>:8443` とペアリングコードを入力する。
`127.0.0.1` はスマホでは PC を指さない。Web 版にも HTTPS が必要。
設定後はスマホもアプリの環境選択だけで切り替えられる。
この経路だけを消すには `tailscale serve --https=8443 off` を使う。

## 自動起動と保存先

| 項目                        | 保存先（既定）                                              |
| --------------------------- | ----------------------------------------------------------- |
| ホスト側 profile            | `~/.local/state/t3-sandbox/profiles/<account>.json`         |
| 履歴・設定・worktree・clone | `~/.local/share/t3-sandbox/<account>/t3/`                   |
| macOS サービス              | `~/Library/LaunchAgents/local.t3-sandbox.<account>.plist`   |
| macOS ログ                  | `~/.local/state/t3-sandbox/logs/<account>.log`              |
| Linux サービス              | `~/.config/systemd/user/local.t3-sandbox.<account>.service` |

データ領域はそのアカウントの sandbox に追加 mount し、ホスト用 profile は mount の外に置く。
XDG_DATA_HOME / XDG_STATE_HOME / XDG_CONFIG_HOME の指定にも対応。
別 workspace / port で setup を再実行した場合は、既存設定を変更せず停止する。
別アカウントを追加しても既存アカウントの T3 とデータを変更しない。
データはホストに永続化されるが、sandbox の削除・再作成は動いている作業を終了し、
追加の provider ログインが必要になることもある。認証情報を template に焼き込まない。

macOS は GUI ログイン後に起動する。Docker Sandboxes 自体も起動しておく。
サービスの異常終了時は再試行するが、PC の電源オフ・スリープ中は接続できない。
Linux は systemd user service が必要。WSL は systemd を有効にし、WSL 自体も起動しておく。
Linux でログアウト後も維持する場合は、管理者の方針に従って lingering を設定する。

診断・保守時だけターミナルを使う:

```bash
mise run t3:ports -- account2
# macOS
launchctl print gui/$(id -u)/local.t3-sandbox.account2
# Linux
systemctl --user status local.t3-sandbox.account2.service
journalctl --user -u local.t3-sandbox.account2.service
```

検証用の `mise run t3:setup -- --no-autostart` と `mise run t3:run -- account2` もあるが普段の運用経路ではない。
サービスと手動 run は同時に起動しない。サービスを止める際は実行中の作業を確認する。
sandbox を停止するだけだとサービスが再試行する。

## 検証と実機確認

起動・初期設定・CLI 操作・ポート確認は `config/mise/tasks/t3.toml` にまとめている。
自動起動サービスも同じ `mise run t3:run` を呼び出す。
この作業環境には `sbx` と `/dev/kvm` がないため、**microVM、LaunchAgent / systemd の実起動、
実際の Claude 認証とスマホ接続は未確認**。
実機ではアプリで作った複数スレッドが別 worktree・同一アカウントの sbx を使うこと、
アカウント切替、PC 再ログイン後の再接続を確認する。

参考: [公式 README](https://github.com/pingdotgg/t3code)、
[リモートアクセス](https://github.com/pingdotgg/t3code/blob/main/docs/user/remote-access.md)、
[worktree 設定](https://github.com/pingdotgg/t3code/blob/main/docs/user/project-settings.md)。
