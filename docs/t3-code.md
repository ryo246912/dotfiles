# T3 Code — 普段はアプリだけで操作する

初回だけターミナルでアカウントと接続を設定する。以降は T3 Code アプリから
新規セッション・再開・実装・差分確認・コミット・PR 作成まで操作する。

- **アカウントごとに常駐 sbx を一つ**用意し、その中で T3 サーバーとエージェントを動かす。
- **worktree はセッションごと**に T3 が作成する。同じアカウントのセッションは sbx を共有する。
- デスクトップもスマホも同じサーバーに接続するので、同じセッションと履歴を見られる。
- 日常の操作でターミナルの常駐は必要ない。

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
6. 初回にプロジェクトが未登録なら、コマンドパレットの **Add project** → **Local folder** から
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
| ports          | sandbox の公開ポートを表示                                      |
| server-status  | ホスト側 T3 サービスの状態                                      |
| restart-server | ホストサービスと対象 sbx を停止し、自動起動定義を更新して再起動 |
| version / help | T3 のバージョン / ヘルプ                                        |

`restart-server` は、ホストサービスの停止 → 対象アカウントの sandbox の停止 →
サービスの再登録・起動の順に行う。ホストの `sbx exec` 接続だけでなく、sandbox 内の T3 プロセスも終了させる。
同じアカウント内の実行中の作業は中断するため、終了してから選ぶ。
保存済みのコード・履歴・認証情報は保持し、sandbox 自体は削除しない。
`--no-autostart` で設定したアカウントでは、自動起動を勝手に登録せずエラーにする。
自動起動が必要なら `t3:setup` を `--no-autostart` なしで再実行する。

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

### T3 Connect を sbx 内で使うためのバージョン

sbx 内でも T3 Connect を利用する構成を目指す。Tailscale は必須ではなく、
T3 Connect の経路が使えない場合の代替手段。
スマホから T3 Connect を使う際は、スマホ側に Tailscale / VPN は必要ない。

sbx 0.53 / 0.54 系の DNS プロキシでは SRV / TXT を解決できず、
cloudflared が接続先を発見できない問題が報告されている。
[公式 issue #791](https://github.com/docker/sbx-releases/issues/791) では、
[0.55.0-rc4 に修正を収録したとの回答](https://github.com/docker/sbx-releases/issues/791#issuecomment-7008656990)
がある。公開 Linux バイナリでも、0.54.0 にはなかった DNS プロキシの
`ResolveSRV` / `ResolveTXT` 処理が 0.55.0-rc4 に含まれることを確認した。
ただし、この作業環境では macOS の既存 sandbox からの実接続は検証できていない。

このため macOS の mise 設定は **0.55.0-rc4（正式版ではない）** に固定する。
最新の正式版 0.54.0 へ更新するだけでは、この修正は取り込まれない。
正式版 0.55.0 以降の公開時には、収録状況を確認して固定バージョンを更新する。

更新は実行中の全 sandbox の作業を保存・終了してから行う。
sbx のデーモンはホストで共有され、再起動の影響は T3 のアカウントだけに限られない。

```sh
cd /path/to/dotfiles
mise bootstrap dotfiles apply
mise install github:docker/sbx-releases
sbx version
sbx daemon restart
sbx diagnose
```

`sbx version` が 0.55.0-rc4 を示し、`sbx diagnose` で CLI とデーモンの
バージョンが一致することを確認する。インストールだけでは、旧デーモンが
動いたままの可能性がある。別のインストール先の sbx を使っている場合は
`command -v sbx` も確認する。

続いて `mise run t3:cli` で設定済みアカウント → **restart-server** を選び、
各アカウントの `connect status` を確認する。work3 の例:

```sh
mise run t3:cli -- work3 connect status
```

接続可能になったらスマホの T3 Code アプリで同じ T3 Connect アカウントにログインし、
環境を開く。バージョン更新だけを理由に sandbox を削除・再作成しない。
SRV エラーが残る場合はデーモンのバージョンと最新のトンネルログ、
DNS 解決後に別のエラーへ進んだ場合は TCP 7844 の許可・到達性を確認する。
DNS 修正の収録と、実際のトンネル接続成功は分けて確認する。

cloudflared は通常の SRV 解決が失敗すると、`1.1.1.1:853` への DoT も試す。
そのため「sandbox 内では SRV 問題を回避する経路が一切ない」とは断定できない。
ただし実機では、Mac の TCP 接続が成功する一方、sandbox 内の DoT は TLS
ハンドシェイクでタイムアウトし、透過プロキシに `<dial failed>` が記録されている。
SNI と接続先 IP の扱いが原因かは未確定。DNS 修正版への更新を先に検証し、
証明書検証の無効化や全通信許可で代用しない。

### sbx から接続するためのネットワーク設定

T3 用の task は `sbx policy allow network --sandbox t3-work3 ...` のように、
対象の sandbox に限定して次の許可を設定する。
setup・サービス起動・CLI の connect 実行時に適用するため、既存 sandbox にも反映される。

| 用途                            | 接続先                                                                                         | 通信               |
| ------------------------------- | ---------------------------------------------------------------------------------------------- | ------------------ |
| T3 Connect の認証・登録・リレー | `clerk.t3.codes` / `relay.t3.codes` / `app.t3.codes`                                           | TCP 443            |
| 暗号化 DNS                      | `cloudflare-dns.com`                                                                           | TCP 853            |
| Cloudflare Tunnel の接続先 SNI  | `_v2-origintunneld._tcp.argotunnel.com`                                                        | TCP 7844（HTTP/2） |
| Cloudflare Tunnel               | `region1.v2.argotunnel.com` / `region2.v2.argotunnel.com` / `cftunnel.com` / `h2.cftunnel.com` | TCP 7844           |

`cloudflare-dns.com:853` は実機ログで拒否が観測されたため許可している。
T3 専用ではなく汎用 DNS への経路になるため、sandbox の DNS 名前制限を迂回した
名前解決や DNS 経由のデータ送信にも利用できる点に注意する。
この許可が全環境で必要かは未確認。接続先 IP は `1.1.1.1`、TLS の SNI は
`cloudflare-dns.com` であり、許可ログの名前と実際の接続先を区別する。

T3 の起動時には `TUNNEL_TRANSPORT_PROTOCOL=http2` を設定し、
トンネルを上記の TCP 7844 で接続する。UDP / QUIC の許可は追加しない。
その他の sandbox の共通 policy は変更しない。

sandbox の許可に加え、Mac から外部への TCP 443・853・7844 が利用できる必要がある。
回線・ルーター・VPN・ファイアウォールが遮断している通信は、sbx の許可では解消できない。
Mac で暗号化 DNS への到達性を確認するには次を実行する。

```sh
nc -vz -G 5 1.1.1.1 853
```

`cloudflare-dns.com` の Web 用 IP に対する TCP 853 の確認では代用できない。
以前案内したホスト名でのタイムアウトだけでは、回線の TCP 853 遮断は判断できない。
上記の `1.1.1.1` で `Operation timed out` になる場合は、別の回線（スマホのテザリングなど）でも比較し、
利用中のネットワークの制限を確認する。
`sbx policy log t3-work3` の `BLOCKED REQUESTS` は sandbox の拒否、
`ALLOWED REQUESTS` の `<dial failed>` は許可後の接続失敗を示す。
過去の拒否行は残るため、`LAST SEEN` も確認する。
SNI の許可は DNS 問い合わせの許可とは異なり、SRV 応答の問題を修復するものではない。

#### 既知の制約: sbx 内の cloudflared は edge に接続できない

実機（sbx v0.53.0）で、sandbox の DNS プロキシが SRV / TXT 問い合わせに NOTIMP（rcode 4）を返し、
A レコードのみ解決することを確認した。cloudflared は edge の検出に
`_v2-origintunneld._tcp.argotunnel.com`（SRV）と `cfd-features.argotunnel.com`（TXT）を使うため、
`server misbehaving` で失敗する。`@1.1.1.1` への直接の DNS（53 番）も、UDP は拒否・TCP は EOF だった。

cloudflared は失敗後に `1.1.1.1:853`（SNI は `cloudflare-dns.com`）への DNS-over-TLS へ
フォールバックするが、透過プロキシのログでは接続先が `cloudflare-dns.com:853` として扱われ、
`<dial failed>` が繰り返される。ホストでは `1.1.1.1:853` に TCP 接続できる一方、
`cloudflare-dns.com` が解決する Web 用 IP の 853 はタイムアウトする。
そのため、透過プロキシがホスト名で接続し直している可能性が高い（接続先の再解決自体は未確認）。
`1.1.1.1:853` を sandbox 限定で許可しても、ハンドシェイクは成功しなかった。

この制約は sbx 側の DNS・透過プロキシの挙動によるもので、dotfiles の network allow では解消できない。

SRV/TXT の修正と固定バージョンは「T3 Connect を sbx 内で使うためのバージョン」に記載している。
v0.55.0-rc4 を `t3-work3` で実機確認したところ、SRV / TXT は応答するようになり、
cloudflared は edge IP（`198.41.192.x`）を取得できた。ただし T3 Connect はまだ接続できない:

- 7844 番への TLS ハンドシェイクが `EOF` で失敗する。
- ポリシーログでは `h2.cftunnel.com:7844` と `probe.cftunnel.com:7844` が、
  許可済みでも透過プロキシで `<dial failed>` になる。
- この 2 つは cloudflared が SNI にだけ使う名前で、DNS には存在しない（`dig` が空）。
  一方、ホストからは edge IP の TCP 7844 に接続できる。
- DoT の `cloudflare-dns.com:853` と同じ挙動で、透過プロキシが SNI の名前を宛先として
  解決し直している可能性が高い（未確認）。`1.1.1.1:853` や `probe.cftunnel.com:7844` の許可を足しても変わらない。

そのため、v0.55.0-rc4 でも T3 Connect は使えない。スマホ接続は下記の Tailscale を使う。
sbx のリリース後に、`dig` で SRV が引けることと、`connect status` の
`reachable` を再確認する。

タスク更新後は `mise run t3:cli -- work3 restart-server` で起動設定を反映する。
この操作は対象 sandbox の実行中の作業を中断するため、先に終了する。
続いて `mise run t3:cli -- work3 connect status` で接続状態を確認し、
接続できない場合は次のトンネルログを確認する。
アカウントが異なる場合はコマンドとパスの `work3` を置き換える。

```sh
tail -n 50 "${XDG_DATA_HOME:-$HOME/.local/share}/t3-sandbox/work3/t3/userdata/logs/relay-client.ndjson"
```

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

sbx 内の cloudflared が動かない（前節の既知の制約）ため、スマホはホスト側の Tailscale で接続する。
T3 Connect の中継を使わず、sbx の DNS 制限も受けない。

前提（初回のみ）:

- Mac とスマホに Tailscale を導入し、同じ tailnet にログインする。
- 管理画面（https://login.tailscale.com/admin/dns）で MagicDNS と HTTPS Certificates を有効にする。
- Mac は起動したままにする（スリープ中は接続できない）。スマホは Tailscale の VPN をオンにする。

```bash
mise run t3:cli -- work3 tailscale
```

`tailscale` はホストの `tailscale serve --bg` で、sandbox の公開ポートを tailnet の HTTPS に出し、
スマホ用の pairing token を発行する。`serve` の設定は永続し、場所を変えても tailnet のアドレスは変わらない。
HTTPS ポートは Tailscale Serve の制約（443 / 8443 / 10000）によりアカウントごとに固定する。

| アカウント | sandbox 公開ポート | tailnet の HTTPS ポート |
| ---------- | ------------------ | ----------------------- |
| account1   | 3773               | 443                     |
| account2   | 3774               | 10000                   |
| work3      | 3775               | 8443                    |

スマホの Add environment に、表示された `https://<MagicDNS名>:<port>` と Token を入力する。
`127.0.0.1` はスマホでは PC を指さない。Token は一度使うと無効で、10 分で期限が切れる。
ブラウザで Pair URL を開くと Token を使い切るため、アプリに直接入力する。
接続後はアプリの環境選択だけで使え、再実行は Token の期限切れ・端末の追加時のみ。
この経路だけを消すには `tailscale serve --https=8443 off` のように、対応するポートを指定する。

Tailscale は private ホストで `mise run bootstrap:mac-packages` が導入する（`tailscale-app`）。
`mise bootstrap packages apply brew-cask:tailscale-app` は、pkg インストーラの sudo 要求で
実機では中断したため使わない。

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
mise run t3:cli -- account2 ports
# macOS
launchctl print gui/$(id -u)/local.t3-sandbox.account2
# Linux
systemctl --user status local.t3-sandbox.account2.service
journalctl --user -u local.t3-sandbox.account2.service
```

サービスを止める際は実行中の作業を確認する。
sandbox を停止するだけだとサービスが再試行する。
sandbox を削除した場合はサービス経由ではなく、対象アカウントと同じ workspace を指定して（以下は work3 の例）
`mise run t3:setup -- --account work3 --workspace /path/to/project` を実行し、
再作成時の plan を手動で確認・承認する。サービスからの無条件な自動承認は行わない。

## 検証と実機確認

mise タスクは初回設定の `t3:setup` と、接続・診断用の `t3:cli` の二つだけ。
ポート確認・サービス状態・再起動も `t3:cli` のメニューから実行できる。
処理本体は `local/bin/t3-sandbox` の Python スクリプトに置き、
自動起動サービスは mise でツール環境を読み込んでから、このスクリプトを直接呼び出す。

以前のタスク定義から更新する場合は、dotfiles の checkout root へ移動して配置する。

```sh
cd /path/to/dotfiles
mise bootstrap dotfiles apply
```

続いて `mise run t3:cli` で設定済みアカウント → **restart-server** を選ぶ。
設定済みの `account1` / `account2` / `work3` それぞれについて一度実行する。
これで既存サービスの呼び出し先も更新される。実行中の作業は先に終了する。
この作業環境には `sbx` と `/dev/kvm` がないため、**microVM、LaunchAgent / systemd の実起動、
実際の Claude 認証とスマホ接続は未確認**。
実機ではアプリで作った複数スレッドが別 worktree・同一アカウントの sbx を使うこと、
アカウント切替、PC 再ログイン後の再接続を確認する。

参考: [公式 README](https://github.com/pingdotgg/t3code)、
[リモートアクセス](https://github.com/pingdotgg/t3code/blob/main/docs/user/remote-access.md)、
[worktree 設定](https://github.com/pingdotgg/t3code/blob/main/docs/user/project-settings.md)。
