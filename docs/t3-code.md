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
専用の `t3-account1` / `t3-account2` / `t3-work3` を作る。同名の sandbox がある場合は再利用されるため、初回は専用名との衝突がないことを確認する。
既存 sandbox の mount は setup では更新されない。構成が違う場合は必要なデータを保存し、
対象 sandbox を停止・削除してから setup で作り直す（自動削除はしない）。
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
`fzf` で Tab / Shift-Tab を使って複数選択し、Enter で確定する。
Ctrl-A で全選択、Ctrl-D で選択解除、Esc で設定を変更せず中止できる。
`fzf` が未導入なら `mise install aqua:junegunn/fzf` で導入する。
開始前に表示される Workspace が、操作しているプロジェクトのパスであることを確認する。

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
# 複数アカウントをまとめて準備する場合
mise run t3:setup -- --account account1 account2 work3 --workspace "$PWD"
```

`sandbox:setup` が行う認証 binding も必要。詳細は [Docker Sandboxes](docker-sandboxes.md) を参照。
Codex など他の provider の認証は sandbox 内の T3 Providers 設定で別途行う。
このアカウント選択が切り替えるのは Claude の subscription 認証。

setup は sandbox を準備し、新規セッションの既定値として `defaultThreadEnvMode: "worktree"`
を設定する。既存の T3 設定は上書きしない。macOS では LaunchAgent、Linux では systemd user
service を登録して T3 をバックグラウンドで起動する。同じ設定で setup を再実行しても、
実行中のサービスを再起動しない。
複数選択時もアカウントごとに別の sbx・ポート・データを使うので同時起動できる。
CPU・メモリの使用量は増えるため、必要なアカウントだけ選ぶ。`--port` の指定は単一選択時だけ利用できる。
選択した全アカウントの token と profile を確認してから準備を始める。
途中で起動処理が失敗した場合、それまでに完了したアカウントの設定は保持する。

以前の版でホームディレクトリを Git リポジトリとして参照するエラーが出る場合は、
タスク定義を更新するまで `--workspace "$PWD"` を付けると、シェルで選んだプロジェクトを明示できる。

## デスクトップアプリを最初に接続する

1. ホストの T3 Code アプリを開く。
2. Settings → Environments で **Local environment をオフ**にし、アプリをリモート操作用にする。
3. 初回だけ `mise run t3:cli` を実行し、fzf で設定済みアカウント → **pair** を選ぶ。
4. 出力の **Address** と **Token** を Add environment に入力するか、**App link** を開く。
   PC から到達できる `http://127.0.0.1:3774` などの URL に変換して表示する。
5. 必要なら表示名を `account2` などに変更し、Providers で Claude の認証状態を確認する。
6. 初回にプロジェクトが未登録なら、コマンドパレットの **Add existing project** から
   setup で指定した workspace を追加する。

サービス起動直後に pair が「サーバーがない」と返す場合は、起動完了後に再実行する。
ペアリングは端末ごとに一度だけでよい。URL / コードは認証情報なのでコミット・共有しない。
複数アカウントを使う場合は、それぞれ一度 setup と接続を行う。
**以降のアカウント切替はアプリの接続先環境を選ぶだけ**。

引数を覚えていなくても `mise run t3:cli` からアカウントと操作を選択できる。
アカウントだけ指定した `mise run t3:cli -- work3` はコマンドの選択画面を開く。
直接の `mise run t3:cli -- work3 pair` も引き続き使える。

| fzf のコマンド | 操作                                                            |
| -------------- | --------------------------------------------------------------- |
| pair           | PC のアプリ接続用 Address / Token / URL を発行                  |
| connect        | T3 Connect の初回認証（スマホ接続用）                           |
| sessions       | 接続を許可した端末の一覧                                        |
| server-status  | ホスト側 T3 サービスの状態                                      |
| restart-server | ホストサービスと対象 sbx を停止し、自動起動定義を更新して再起動 |
| version / help | T3 のバージョン / ヘルプ                                        |

`restart-server` は、ホストサービスの停止 → 対象アカウントの sandbox の停止 →
サービスの再登録・起動の順に行う。ホストの `sbx exec` 接続だけでなく、sandbox 内の T3 プロセスも終了させる。
同じアカウント内の実行中の作業は中断するため、終了してから選ぶ。
保存済みのコード・履歴・認証情報は保持し、sandbox 自体は削除しない。

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

## スマホ・別の PC のアプリから接続する（初回のみ）

T3 Connect に sandbox の環境を登録すると、デスクトップ・iOS・Android の T3 Code アプリや
https://app.t3.codes から同じセッションを開ける。T3 Connect のログインは、sandbox に固定した
Claude の `account1` / `account2` / `work3` とは別のもの。

### ホストで T3 Connect に登録する

1. `mise run t3:cli` を実行し、公開するアカウント（例: **work3**）→ **connect** を選ぶ。
   その sandbox に必要な通信先を許可してから、sandbox 内で `t3 connect link --headless` が実行される。
2. relay client の導入確認が出たら **`y` を入力して Enter** を押す。
   Enter だけでは既定の `N` になる。表示バージョンは T3 が指定するものを使う。

   ```text
   The T3 relay client is required for T3 Connect.
   Download and install version 2026.10.4? › (y/N)
   ```

   relay client は T3 Connect の通信用ツールで、選択した sandbox 内に取得・導入される。
   ホストへの別途インストール操作は必要ない。

3. 続いて表示される **認証 URL** をブラウザーで開き、T3 Connect にログインする。
   ターミナルのコードと画面のコードが一致することを確認して承認する。
4. ターミナルへ戻り、**`✓ Authorized`** と表示されて処理が完了するまで待つ。
5. 再び `mise run t3:cli` を実行し、同じアカウント → **restart-server** を選ぶ。
   実行中の作業があれば先に終了する。認証を保存した後に T3 サーバーを起動し直すと、
   T3 Connect の接続が有効になる。この構成のサーバー起動はホストの自動起動サービスで管理する。

既に PC のアプリへ pair で接続済みなら、対象環境の Settings → Sharing & access から
**T3 Connect** を有効化して本人認証する方法も使える。

T3 用の task は `sbx policy allow network --sandbox t3-work3 ...` のように、対象の sandbox に限定して
認証・リレー用の `clerk.t3.codes:443` / `relay.t3.codes:443` / `app.t3.codes:443` と、
暗号化 DNS 用の `cloudflare-dns.com:853`、
Cloudflare Tunnel の `region1.v2.argotunnel.com` / `region2.v2.argotunnel.com` /
`cftunnel.com` / `h2.cftunnel.com` の TCP 7844 を許可する。
setup・サービス起動・CLI の connect 実行時に適用するため、既存 sandbox にも反映される。
その他の sandbox の共通 policy は変更しない。

### 接続先のアプリで同じ環境を開く

1. 接続する端末に [公式 T3 Code アプリ](https://t3.codes/download) を導入する。
   スマホは公式サイトから案内される App Store / Google Play のアプリを使う。
   ブラウザーなら https://app.t3.codes を開く。
2. アプリの **T3 Connect** から、ホストの認証で使ったものと **同じアカウント** にログインする。
3. 環境一覧から、登録した sandbox の環境を選ぶ。複数アカウントを登録している場合は、
   作業したいアカウントの環境を選ぶ。
4. プロジェクト・既存スレッドを開くと、PC と同じセッションを閲覧・操作できる。
   以降はアプリで環境を選ぶだけでよく、毎回の `connect` や `pair` は不要。

新規デバイス承認を有効にしている場合は、既に接続済みの PC の
Settings → Sharing & access で新しい端末のコードを確認して承認する。
PC・sandbox・T3 サーバーは起動した状態を維持する。
標準上限は 3 環境なので、3 アカウントの sandbox を公開すると 3 台分になる。

### Tailscale で接続する場合

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
Linux は対応環境に sbx を別途導入し、systemd user service を利用する必要がある。
このリポジトリの sbx 導入設定は macOS 用。WSL2 ではこの microVM 構成は利用できない。
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
sandbox を削除した場合はサービス経由ではなく、対象アカウントと同じ workspace を指定して（以下は work3 の例）
`mise run t3:setup -- --account work3 --workspace /path/to/project` を実行し、
再作成時の plan を手動で確認・承認する。サービスからの無条件な自動承認は行わない。

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
