# T3 Code — 普段はアプリだけで操作する

初回だけターミナルでアカウントと接続を設定する。以降は T3 Code アプリから
新規セッション・再開・実装・差分確認・コミット・PR 作成まで操作する。

- **T3 環境ごとに常駐 sbx を一つ**用意し、その中で T3 サーバーとエージェントを動かす。
- **worktree はスレッドのワークスペース設定に応じて** T3 が作成する。同じ T3 環境のセッションは sbx を共有する。
- デスクトップもスマホも同じサーバーに接続するので、同じセッションと履歴を見られる。
- 日常の操作でターミナルの常駐は必要ない。

## 全体構成

要点は 3 つ。

1. **sandbox は Git リポジトリのルートパスとアカウントの組み合わせごとに 1 つ**。
2. **T3 サーバーも sandbox の中に 1 つ**。このサーバーが、そのアカウントのエージェント（Claude Code / Codex）を動かす。
3. **worktree はスレッドごとに選べる**。subscription プロファイルの初期値は worktree、OAuth の初期値は現在のチェックアウト。実装前に作業先表示を確認する（後述）。

PC とスマホのアプリで同じ環境に接続すると、同じセッションと履歴を操作できる。
以下は、`xxx` に OAuth 環境、`yyy` に account1 環境を作った例。

```text
T3 Code アプリ（接続先を切り替え）
  PC はローカルの公開ポート、スマホは T3 Connect で接続
  公開ポート枠: oauth 3800–3809 / account1 3810–3819
                account2 3820–3829 / work3 3830–3839
  │
  └─ Mac（ホスト）
      ├─ 127.0.0.1:3800 → xxx-oauth-<パスのハッシュ>-t3
      │                    ├─ T3 サーバー（sandbox 内の :3773）
      │                    ├─ workspace: xxx
      │                    └─ T3 の設定・履歴: xxx の環境の保存先
      │
      └─ 127.0.0.1:3810 → yyy-a1-<パスのハッシュ>-t3
                           ├─ T3 サーバー（sandbox 内の :3773）
                           ├─ workspace: yyy
                           └─ T3 の設定・履歴: yyy の環境の保存先
```

各環境にはアカウントごとの枠から空いている公開ポートを1つ割り当てる。

### 各部品の役割

| 部品                    | 数                 | 役割                                                                                                                                                                            |
| ----------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| sbx（sandbox）          | T3 環境ごとに 1    | 隔離された実行環境。network policy は sandbox ごとに設定できる。ただしホストの共通設定や書き込み可能な `agent-lessons` も mount されるため、信頼できる agent だけを動かす前提。 |
| T3 サーバー             | sbx ごとに 1       | thread・履歴・認証を持ち、エージェントを起動する。ホストの自動起動（launchd / systemd）が維持する。                                                                             |
| thread（セッション）    | 好きなだけ         | 1 つの作業の単位。選んだチェックアウトまたは worktree でエージェントが動く。                                                                                                    |
| worktree                | 必要な thread ごと | thread の変更を隔離する Git の作業ツリー。新しいワークツリーを選ぶと T3 が作成する。                                                                                            |
| T3 アプリ（PC・スマホ） | 何台でも           | サーバーへの画面。接続先は同じなので、どの端末から見ても同じ状態になる。                                                                                                        |

### よくある疑問

- **sandbox の中で worktree を切るのか**: 新しいワークツリーを選んだ場合は、T3 サーバーが sandbox 内で作成する。
  subscription の初期値は worktree、OAuth の初期値は現在のチェックアウト。
- **セッションごとに sandbox が増えるのか**: 同じ T3 環境で始めたセッションは 1 つの sandbox を共有する。
  同じアカウントでも、リポジトリ別の環境を追加した場合は専用の sandbox ができる。
- **スマホでは何が見えるのか**: スマホから接続したサーバー（接続先の sandbox）の thread とその履歴。
  リポジトリ別の環境をそれぞれアプリに追加できる。
- **別のアカウントの sandbox のエージェントも同じ画面で見られるのか**: アプリに各環境を追加すれば切り替えて見られる。
  セッションと履歴はサーバーごとに保存される。
- **ターミナルや ccmanager で動かしたエージェントは見えるのか**: 見えない。T3 に表示されるのは、
  T3 自身が起動した thread だけ。スマホで見たい作業は、T3 アプリから新規セッションとして始める。

### スマホからの接続

スマホは T3 Connect で接続する。sbx 0.55.0-rc4 以降、`feature.udp-egress` の有効化、
QUIC と UDP 7844 の許可が必要。接続の準備は「スマホ・別の PC のアプリから接続する」を参照する。

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

クリップボードや Claude の Chrome 連携などのホスト設定も有効にする場合は、
別途 `mise run sandbox:sbx-settings` を実行する。このタスクは sbx デーモンを再起動する。

template は T3 追加後に再ビルドする。セットアップではリポジトリとアカウントの組み合わせに対応する sandbox を作る。同名の sandbox がある場合は再利用する。
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

`account1`・`account2`・`work3`・`oauth` の選択メニューが出る。上の3つは既存の Claude サブスク用
アカウント名で、`oauth` は通常の sbx OAuth を使うプロファイル。T3 Connect のログインは別途設定する。
`fzf` で Tab / Shift-Tab を使って複数選択し、Enter で確定する。
Ctrl-A で全選択、Ctrl-D で選択解除、Esc で設定を変更せず中止できる。
`fzf` が未導入なら `mise install aqua:junegunn/fzf` で導入する。
開始前に表示される Workspace が、操作しているプロジェクトのパスであることを確認する。

subscription プロファイルは `sbx-agent --claude-account` と subscription kit を使い、
Claude の認証先をその sandbox に固定する。token が未登録の場合は停止する。

```bash
mise run sandbox:claude-token account2
# メニューを使わず指定する場合
mise run t3:setup -- --sbx account2 --workspace /path/to/project
# 複数アカウントをまとめて準備する場合
mise run t3:setup -- --sbx account1 account2 work3 --workspace "$PWD"
```

`sandbox:setup` が行う認証 binding も必要。詳細は [Docker Sandboxes](docker-sandboxes.md) を参照。
アカウント選択は Claude の認証方式を決める。Codex のログイン手順は後述。

setup は sandbox を準備し、subscription プロファイルの新規スレッドは worktree、
OAuth プロファイルは現在のチェックアウトを初期値にする。既存の T3 設定は上書きしない。macOS では LaunchAgent、Linux では systemd user
service を登録して T3 をバックグラウンドで起動する。同じ設定で setup を再実行しても、
実行中のサービスを再起動しない。
複数選択時もアカウントごとに別の sbx・ポート・データを使うので同時起動できる。
CPU・メモリの使用量は増えるため、必要なアカウントだけ選ぶ。`--port` の指定は単一選択時だけ利用できる。
選択した全アカウントの token と profile を確認してから準備を始める。
途中で起動処理が失敗した場合、それまでに完了したアカウントの設定は保持する。

### リポジトリ別の T3 環境を作る

T3 Code アプリに接続したいリポジトリのルートで次を実行する。
以下は `yyy` の例。

```sh
cd /path/to/yyy
mise run t3:setup
mise run t3:cli
```

セットアップでは fzf でアカウントを選び、CLI では **pair → 同じアカウント** を選ぶ。
サブディレクトリからの実行でも Git が検出したルートを使う。別の場所からセットアップする場合は、
`--workspace /path/to/repo` で対象を指定できる。ペアリングは対象リポジトリ内で実行する。

セットアップは Git のルートパスとアカウントを使い、sandbox、設定・履歴、ホストの自動起動を
個別に作る。sandbox 名には CCManager の preset と同じ `a1`、`a2`、`w3`、`oauth` が入る。

| 選択するアカウント | sandbox 名の例                  |
| ------------------ | ------------------------------- |
| account1           | `xxx-a1-<パスのハッシュ>-t3`    |
| account2           | `xxx-a2-<パスのハッシュ>-t3`    |
| work3              | `yyy-w3-<パスのハッシュ>-t3`    |
| oauth              | `yyy-oauth-<パスのハッシュ>-t3` |

リポジトリ名は Git ルートの末尾の名前を小文字にし、英数字以外をハイフンに置き換える。
同名のリポジトリを別の場所に clone した場合も別環境になる。
初回はアカウントごとに次の枠から空きポートを自動で割り当てる。

| アカウント | ホストの公開ポート |
| ---------- | ------------------ |
| oauth      | 3800–3809          |
| account1   | 3810–3819          |
| account2   | 3820–3829          |
| work3      | 3830–3839          |

`--port` で初回のポートを指定する場合も、そのアカウントの枠を使う。
枠が埋まっている場合はセットアップ時にエラーを表示する。
セットアップ済みの環境は、枠外であっても登録済みポートを再利用する。
前回のセットアップが途中で止まり、sandbox に公開ポートだけ設定済みの場合も、そのポートを再利用する。
リポジトリ別環境のアプリ接続にはローカルの `pair` または T3 Connect を使う。
同じ T3 Connect アカウントで登録できるのは、全リポジトリの環境を合計して標準で 3 環境まで。
PC のローカル `pair` はこの枠を使わない。

T3 を使わずにリポジトリで Claude を直接開く場合は
`sbx-agent claude --claude-oauth --name-prefix oauth` を使える。
通常の `sbx-agent` はリポジトリ名・ブランチ名で sandbox 名を組み立てる。

以前の版でホームディレクトリを Git リポジトリとして参照するエラーが出る場合は、
タスク定義を更新するまで `--workspace "$PWD"` を付けると、シェルで選んだプロジェクトを明示できる。

## OAuth 用の Sandbox と MCP

ホストで、使いたい remote MCP を専用の名前で登録し、ブラウザで目的のアカウントを選んで認可する。
既存の MCP 登録を指定すると、その登録の認可を再利用する。認可先を分ける場合は別名で登録する。

```bash
sbx mcp add notion-t3-oauth --url https://mcp.notion.com/mcp
sbx mcp auth notion-t3-oauth
cd /path/to/project
mise run t3:setup
# oauth を選択して Sandbox を作成
mise run sandbox:mcp-load
# セットアップで表示された Sandbox 名と、その Sandbox で使う MCP を選択
mise run t3:cli
```

**login → Claude → oauth** を選ぶと専用 Sandbox の Claude が開く。
必要に応じて `/login` を実行し、`/mcp` でツールを確認する。続いて **pair → oauth** で T3 アプリを接続する。
Claude OAuth は既存の ccmanager OAuth プリセットと同じ sbx のホスト共通認証を使う。
T3 の `oauth` プロファイルでは起動時に Claude in Chrome を有効にする。
ホストで `sbx settings set claude.chrome true` を設定し、Chrome 拡張には Claude の `/login` と同じアカウントでログインする。
起動済みの T3 サーバーには **restart-server → oauth** で反映し、新規 Claude スレッドで確認する。
MCP 側の OAuth はそれぞれの MCP 登録で管理する。T3 に接続したら、新規スレッドのツール一覧でも確認する。

`sandbox:mcp-load` は選んだ MCP で割り当てを置き換える。引き続き使う MCP も Tab で選ぶ。
引数を省略すると Sandbox も fzf で選べる。手動で登録した名前が
`sandbox:mcp-add` で未定義と表示されても、`sbx mcp rm` すると登録と OAuth 認可が消える。
T3 アプリ内では必要なスレッドだけ入力欄で **新しいワークツリー** を選べる。

## 同じ Sandbox で Codex も使う

Claude 用イメージにも mise で Codex CLI が入る。Codex は同じ Sandbox 内で個別に認証できる。
次の操作は対象 Sandbox に Codex の OpenAI 接続先を許可し、デバイス認証を開始する。
表示された URL をホストのブラウザで開く。ChatGPT 側でデバイスコード認証を許可する必要がある場合は先に有効にする。

```bash
mise run t3:cli
```

**login → Codex → 対象 Sandbox** を選ぶ。subscription の Sandbox でも同じ操作ができる。
ログイン後、対象の T3 環境を選び、**Settings → Providers → Codex** で有効化・更新する。
CLI の場所を指定する場合は `/mise/data/shims/codex` を使う。
新規スレッドのモデル選択で Claude と Codex を切り替える。
この手順で追加するのは Codex 本体の認証。Codex から同じ MCP を使うには、
Codex 側で別途 MCP を設定する。Claude workload の MCP 自動登録は Claude に適用される。

## デスクトップアプリを最初に接続する

1. ホストの T3 Code アプリを開く。
2. Settings → Environments で **Local environment をオフ**にし、アプリをリモート操作用にする。
3. 初回だけ `mise run t3:cli` を実行し、fzf で **pair** → 設定済みの Sandbox を選ぶ。
4. 出力の **Address** と **Token** を Add environment に入力するか、**App link** を開く。
   PC から到達できる `http://127.0.0.1:3774` などの URL に変換して表示する。
5. 必要なら表示名を `account2` などに変更し、Providers で Claude の認証状態を確認する。
6. 初回にプロジェクトが未登録なら、コマンドパレットの **Add project** → **Local folder** から
   setup で指定した workspace を追加する。

サービス起動直後に pair が「サーバーがない」と返す場合は、起動完了後に再実行する。
ペアリングは端末ごとに一度だけでよい。URL / コードは認証情報なのでコミット・共有しない。
複数アカウントを使う場合は、それぞれ一度 setup と接続を行う。
**以降のアカウント切替はアプリの接続先環境を選ぶだけ**。

`mise run t3:cli` は **操作 → 対象 Sandbox** の順で選ぶ。対象はカレントリポジトリで設定済みの環境。
**login** を選ぶと途中で **Claude / Codex** の選択が入り、その操作に対応した Sandbox が表示される。
スクリプトなどから直接実行する場合は `mise run t3:cli -- --sbx work3 pair` も使える。

| fzf のコマンド | 操作                                                            |
| -------------- | --------------------------------------------------------------- |
| pair           | PC のアプリ接続用 Address / Token / URL を発行                  |
| login          | Claude / Codex を選んでログイン                                 |
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

1. `mise run t3:cli` を実行し、**connect** → 公開する Sandbox（例: **work3**） を選ぶ。
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
5. 認証が正常終了し、選んだ環境の自動起動定義（macOS の LaunchAgent ファイルまたは Linux の systemd unit ファイル）がある場合は、Sandbox と T3 サーバーを自動で再起動する。
   実行中の作業は認証前に終了しておく。自動起動定義がなく手動で起動している場合は、認証後に実行中のサーバーを止めてから `t3-sandbox run <account> --repository /path/to/repo` を実行する。

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

続いて `mise run t3:cli` で**restart-server** → 設定済みの Sandbox を選び、
各アカウントの `connect status` を確認する。work3 の例:

```sh
mise run t3:cli -- --sbx work3 connect status
```

接続可能になったらスマホの T3 Code アプリで同じ T3 Connect アカウントにログインし、
環境を開く。バージョン更新だけを理由に sandbox を削除・再作成しない。
SRV エラーが残る場合はデーモンのバージョンと最新のトンネルログ、
DNS 解決後に別のエラーへ進んだ場合は UDP 7844 の許可と `feature.udp-egress` を確認する。
DNS 修正の収録と、実際のトンネル接続成功は分けて確認する。
証明書検証の無効化や全通信許可で代用しない。

### sbx から接続するためのネットワーク設定

T3 用の task は `sbx policy allow network --sandbox t3-work3 ...` のように、
対象の sandbox に限定して次の許可を設定する。
setup・サービス起動・CLI の connect 実行時に適用するため、既存 sandbox にも反映される。

| 用途                            | 接続先                                                    | 通信          |
| ------------------------------- | --------------------------------------------------------- | ------------- |
| T3 Connect の認証・登録・リレー | `clerk.t3.codes` / `relay.t3.codes` / `app.t3.codes`      | TCP 443       |
| T3 Connect の公開アドレス       | `*.t3coderelay.com`                                       | TCP 443       |
| Cloudflare Tunnel の接続先 SNI  | `_v2-origintunneld._tcp.argotunnel.com`                   | TCP 7844      |
| Cloudflare Tunnel               | `region1.v2.argotunnel.com` / `region2.v2.argotunnel.com` | TCP・UDP 7844 |

`*.t3coderelay.com` は `connect status` が自分の公開アドレスを確認するために必要で、
許可が無いと、トンネルが外から 200 で通っていても sbx のプロキシが 403 を返し、
`NOT reachable`（HTTP 403）と表示される。

T3 の起動時には `TUNNEL_TRANSPORT_PROTOCOL=quic` を設定し、UDP 7844 で接続する。
UDP は sbx の実験機能で、既定では無効のため、ホストで一度だけ有効にする。
これは sbx 全体の設定で、sandbox 単位ではない。

```sh
sbx settings set feature.udp-egress true
```

その他の sandbox の共通 policy は変更しない。

sandbox の許可に加え、Mac から外部への TCP 443・UDP 7844 が利用できる必要がある。
回線・ルーター・VPN・ファイアウォールが遮断している通信は、sbx の許可では解消できない。
`sbx policy log t3-work3` の `BLOCKED REQUESTS` は sandbox の拒否、
`ALLOWED REQUESTS` の `<dial failed>` は許可後の接続失敗を示す。
過去の拒否行は残るため、`LAST SEEN` も確認する。
SNI の許可は DNS 問い合わせの許可とは異なり、SRV 応答の問題を修復するものではない。

#### 経緯: HTTP/2 では接続できず、QUIC を使う理由

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

SRV/TXT の修正と固定バージョンは「T3 Connect を sbx 内で使うためのバージョン」に記載している。
v0.55.0-rc4 では SRV / TXT は応答するようになり、cloudflared は edge IP（`198.41.192.x`）を取得できた。
ただし HTTP/2（TCP 7844）では、TLS ハンドシェイクが `EOF` で失敗する。

- 同じ edge IP に対し、sandbox 内から SNI だけを変えて比べると、
  `region1.v2.argotunnel.com` は成功し、`h2.cftunnel.com` / `cftunnel.com` は即 EOF になった。
  ホストからは `h2.cftunnel.com` でも成功する。
- ポリシーログでは、許可済みの `h2.cftunnel.com:7844` / `probe.cftunnel.com:7844` が
  透過プロキシで `<dial failed>` になる。この 2 つは名前自体は存在する（`dig` は NOERROR）が A レコードが無い。
- 透過プロキシが宛先 IP ではなく SNI のホスト名で接続し直している可能性が高い（内部の動作は未確認）。
  そのため A レコードの無い名前は接続できないと見られる。`1.1.1.1:853` や `probe.cftunnel.com:7844` の許可を足しても変わらない。

QUIC は SNI に `cftunnel.com` 系を使わないため、この問題を避けられる。
`feature.udp-egress` を有効にし、UDP 7844 を許可した `t3-work3` で、
4 本のトンネル接続が QUIC で登録され、`connect status` が接続済みになることを確認した
（スマホの実機での確認は別）。

タスク更新後は `mise run t3:cli -- --sbx work3 restart-server` で起動設定を反映する。
この操作は対象 sandbox の実行中の作業を中断するため、先に終了する。
続いて `mise run t3:cli -- --sbx work3 connect status` で接続状態を確認し、
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
T3 Connect の標準上限は 3 環境。同じ T3 Connect アカウントでは、全リポジトリの環境を合わせて
モバイルから使う環境を 3 つまで選ぶ。PC のローカル接続は T3 Connect の枠を使わない。

## 別ホストのセッションを引き継ぐ

T3 Code に、別ホストで動いているスレッドを手元のホストへ移し替える機能はない。
スレッドは元のホストで動かしたまま、別の端末から接続して続きを操作する。
以下は T3 Code 公式リポジトリ（`pingdotgg/t3code`）の `docs/user/`
に基づく。接続方法は `remote-access.md`、会話の取り込みは `welcome-page.md`、
データの退避は `thread-migration.md` を参照している。
「スレッドを別のサーバーへ移す方法はない」の Linked environments と portable handoff は、
公式ドキュメントの `portable-handoffs.md` などを参照した情報で、このリポジトリの作業では原文を再確認していない。
バージョンにより項目名が異なる可能性がある。

### 1. 元のホストへ接続して続ける（基本）

どのクライアントからも、サーバー上の同じスレッドが見える。
スレッドが動くホストを接続先に登録すれば、別のマシン・ブラウザー・スマホから続きを打てる。

| 方法          | 手順                                                                                                    |
| ------------- | ------------------------------------------------------------------------------------------------------- |
| T3 Connect    | ホストの Settings → Sharing & access で有効化する。CLI のみのホストは `t3 up`。同じアカウントでログイン |
| SSH           | デスクトップアプリの Settings → Environments → Add environment → SSH に `user@host` を入れる            |
| LAN/Tailscale | ホストで `t3 serve --lan` を実行し、`t3 pair` でペアリングする                                          |

元のホストは起動したままにする。この dotfiles の sandbox 構成での手順は
「スマホ・別の PC のアプリから接続する」を参照。

### 2. 別ホストの Claude Code / Codex CLI の会話を取り込む

T3 Code の外で `claude` / `codex` を直接使っていた会話は、取り込める。

1. 上の方法で、そのホストを environment として登録する
2. Settings → Projects → Import projects and their threads を開き、その environment を選ぶ
   （公式の `welcome-page.md` にある手順。初回起動の Welcome ページでも取り込める。
   アプリのバージョンによって画面が異なる場合は、Welcome ページ側の Projects のインポートを使う）
   （Pi の会話も取り込む場合は、先に Add more agents で Pi を有効にする。既定では対象外）
3. Claude Code / Codex / Pi の会話が T3 Code のスレッドとして取り込まれ、続きを打てる
   （取り込まれるのは直近 30 日に活動した会話だけ。それより古い会話は、選んでも取り込まれない）

取り込んだスレッドも、そのホスト上で動く。

取り込みはベストエフォートで、全文の移行ではない（公式の `docs/user/welcome-page.md`）。

- 保持されるのは、最初のユーザープロンプトと、直近の可視メッセージ（最初のプロンプトと合わせて最大 200 件）
- ツールの実行記録と添付ファイルは省略される
- 壊れたセッション、空のセッション、サイズの大きいセッション（4 GiB 超のファイル、
  保持するテキストとメタデータが 32 MiB 超、レコード 100,000 件超）は取り込まれない
- 1 回の取り込みは、プロジェクトごとに最大 100 会話・4 GiB まで。続きは Welcome ページの Review all から行う

重要なコンテキスト（ツールの結果や添付で渡した情報）が欠けたまま続きを打つことになるため、
続ける前に、スレッドの内容を確認して、必要な前提を書き足す。
取り込んだスレッドが、元のプロバイダーのセッションを再開するのか、
会話ログから新しく始めるのかは、ドキュメントに記載が無く未確認。

### 3. スレッドを別のサーバーへ移す方法はない

ドキュメントにも、スレッド全体を書き出すコマンドは無いと書かれている。代替手段は次のとおり。

- **Linked environments（beta）**: 両方のマシンの Settings → Labs で有効にしてリンクすると、
  相手のスレッドを読み取り専用で追える。操作するときは Connect to interact で直接ペアリングする
- **新しいスレッドで引き継ぐ**: 移したい先で新しいスレッドを作り、要点のまとめを貼る。
  プロバイダー切替時にも使われる portable handoff は履歴の一部しか渡さず、
  上限は既定 16k トークン（`T3CODE_CONTEXT_HANDOFF_TOKEN_CAP` で変更可）。
  重要な制約は書き直して渡す
- **データ丸ごとの退避**: 公式はサーバーを止めて `~/.t3/userdata` を退避する方法を案内している。
  この dotfiles の sandbox 構成では、保存先が異なり、
  `${XDG_DATA_HOME:-$HOME/.local/share}/t3-sandbox/<sandbox-name>/t3/userdata` になる
  （「自動起動と保存先」を参照）。スレッド 1 本だけを移す用途には向かない

## T3 Connect の安全性

T3 Connect は、ルーターのポート開放なしでホストと他の端末をつなぐ仕組み。
公式ドキュメントの `remote-access.md` で確認できた範囲を整理する。

### 確認できたこと

- 既定では、**同じ T3 Connect アカウントにログインした端末は、どれでも接続できる**
- 新しい端末の承認を必須にできる。ホストの Settings → Sharing & access で
  **Require approval for new devices** を有効にする。新端末が出す短いコード（10 分有効）を、
  接続済みの端末、または `t3 auth connect-device approve <code>` で承認する
- 端末の失効は Settings → Sharing & access、または `t3 auth connect-device revoke <code>` で行う
- ペアリング済みの端末は使っている間ログインが続き、30 日使わないと再ペアリングが必要になる
- `--scope`（例: `orchestration:read` / `filesystem:write` / `terminal:operate`）で、
  ペアリングやセッションの権限を絞れる。ただし、T3 Connect のログインや端末承認にも効くかは未確認で、
  同じアカウントの端末が既定で接続できる点は変わらない
- 解除は、アカウントメニューの T3 Connect → Deregister、または CLI ホストで
  `t3 connect unlink` / `t3 connect logout`
- 「ペアリング URL とコードはパスワードと同じに扱い、ログやスクリーンショットに貼らない」という注意がある
- T3 Connect 自体に beta / experimental の表示は無い（beta なのは Linked environments）

### リレーの構造と通信内容の見え方

公式リポジトリの `docs/internals/06_t3-connect.md`、`docs/user/faq.md`、`docs/user/telemetry.md`、
`SECURITY.md` に基づく。

**ドキュメントに書かれていること**

- 通常の HTTP / WebSocket の通信は、クライアントからホストの tunnel ホスト名へ直接流れ、
  リレー（Worker）はデータ経路に入らない。通信は Cloudflare Tunnel（ホスト側の `cloudflared`）経由。
  リレーは認証情報の発行と tunnel の割り当てを仲介する
- 例外として、自動化の webhook はリレーを経由する。オフライン保持を有効にすると、
  生のリクエストがリレーの Durable Object に保存される
- リレーは環境のセッショントークンを見ない。認証は DPoP で束縛した認証情報と、
  リレーと環境の相互認証で行う
- リレーが保持するのは、環境のリンク情報、tunnel の割り当て、承認済み端末の鍵指紋など。
  ID 管理は Clerk。webhook のオフライン保持を有効にした場合は、保持中の webhook も含む
- テレメトリは `ingest.t3.codes` へ、ハッシュ化した ID とともに送られる。
  内容はプロバイダー・モデル・トークン数・所要時間などで、プロンプト・応答・ファイル内容・認証情報は含まれない。
  リレーの接続診断（所要時間・リクエストパス・環境/スレッド ID・エラー種別）は Axiom に送られる
- Settings → Sharing & access の「Publish agent activity」を有効にすると、
  プロジェクト/スレッドのタイトル、モデル名、ターンの状態がモバイル通知のためにリレーへ送られる
- `SECURITY.md` は、リレーを mint 要求の「信頼するブローカー」とし、
  リレーの署名鍵が侵害されると、リンク済みの環境向けに認証情報を発行されると明記している
- プロンプトとコードは、ホストから選んだ AI プロバイダーへ直接送られる（FAQ）

**ドキュメントに書かれていないこと**

- アプリケーション層のエンドツーエンド暗号化（E2EE）の記載は見つからなかった。
  セッション鍵や E2EE のハンドシェイクの説明が無く、書かれているのは DPoP と相互認証だけ
- ログの保持期間、アカウント削除の扱い。プライバシーポリシー（`t3.codes/privacy`）は、
  この環境から到達できず読めていない

**メンテナーの公式な発言（E2EE は見送り）**

[pingdotgg/t3code#32098](https://github.com/pingdotgg/t3code/issues/32098)
（T3 Connect はクラウドのアカウントだけでリンク済みマシンを操作できる、という指摘。2026-11-14 にクローズ）で、
メンテナーの juliusmarminge が
[コメント](https://github.com/pingdotgg/t3code/issues/32098#issuecomment-6869049926)
に次のように書いている。

> Full end-to-end encryption with mutual pairing would be a bigger change, and we've left it out for now.

- E2EE は「今は見送った」と明言されている。理由は「変更が大きい」という点だけで、時期の見通しは書かれていない
- 対応として、端末承認（PR #36419）が追加された。既定は無効で、T3 Connect のセットアップ時に案内される。
  無効のままだと、クラウドが新しい端末を登録できる
- このスレッドでは、T3 が会話内容を読めるかには触れていない。tunnel や Workers Routes の話も出ていない

**推測（ドキュメントに記載なし）**

Cloudflare Tunnel は TLS を Cloudflare のエッジで終端する。上記の E2EE が無いなら、
Cloudflare は HTTP / WebSocket の平文（プロンプトや出力を含む）を技術的に読める。
リレー自体はデータ経路に入らないとされるが、Cloudflare 側の可視性は T3 のドキュメントでは扱われていない。

tunnel の作成元は書かれていない。リレーが割り当てを管理する構成なので、
T3 のアカウントで発行・運用している可能性が高い。その場合、T3 側が Workers Routes などで
エッジの通信内容を取得することは、E2EE が無い限り技術的に妨げられない。
これは構造からの推測で、実際に取得していることを示す証拠は見つかっていない。

**未検証の情報（他の人からの情報で、一次情報を確認していない）**

- 競合の Orca / Paseo / Happier は、デバイス間の通信が暗号化され、運営者でも会話内容を見られないという話
- bb は暗号化しないが、プライバシーポリシーで E2EE をしないことと、データを保持しないことを明言しているという話
- T3 Connect にはその種の明言が無いため、会話データを保管している可能性を否定できないという話

第三者による監査（セキュリティ認証など）の有無は確認できていない。

### 判断の目安

- T3 Connect の通信内容は、T3 と中継する Cloudflare に見られうるものとして扱う
  （E2EE が無く、見送りが明言されているため。実際に見ているかは未確認）
- プロンプト、コード、出力に機密を含む作業は、T3 Connect を使わない
  （Tailscale や SSH など、通信内容を第三者に見せない暗号化された経路を使う。
  Tailscale は中継サーバーを経由することもあるが、通信は端末間で暗号化される）
- 上の「確認できたこと」の端末承認・失効・権限の絞り込みは、アカウント乗っ取り対策であり、
  通信内容の秘匿性は変えない

### この構成での注意

T3 Connect に登録した環境からは、エージェントがそのホスト（この構成では sandbox）で
コマンド実行・ファイル操作できる。アカウントが乗っ取られると、接続できる端末が増える。

- T3 Connect のアカウントに 2 段階認証を設定する
- **Require approval for new devices** を有効にする。
  無効のまま端末を失効しても、同じアカウントで再接続できると考えられる（推測）ため、失効だけに頼らない
- 承認を有効にする前に接続した端末は、有効にした後も信頼済みのまま残る
  （#32098 のメンテナー発言）。有効にしたら、一覧で信頼済みの端末を確認し、不明な端末は失効させる
- 使わない端末は失効させ、使わなくなった環境は Deregister する
- 公開するのは、権限を絞った sandbox（この構成では work3 など）の環境だけにする。
  認証情報を多く持つホスト本体は公開しない
- 不安がある場合は T3 Connect を使わず、Tailscale や SSH で接続する

### Tailscale で接続する場合

T3 Connect を使わない経路。通信は Tailscale の暗号化経路で端末間を結ぶので、T3 や Cloudflare の中継を通らず、
sbx の DNS 制限（SRV / TXT）も受けない。機密を含む作業や、T3 Connect が使えない場合（sbx が 0.55.0-rc4 未満、
`feature.udp-egress` が無効など）はこちらを使う。「T3 Connect の安全性」も参照。

以前の `mise run t3:cli -- <アカウント> tailscale` は、#1872 のリポジトリ別 sandbox への移行で削除済み。
以下は、旧コマンドが内部で行っていた処理（`tailscale serve` の設定と pairing token の発行）を手動で行う手順。
このリポジトリの作業環境には Mac・Tailscale・sbx が無く、**現在の構成での実行は未検証**。
手順の途中で失敗したら、`mise run t3:cli` のメニューの `ports` と `server-status` で状態を確認する。

前提（初回のみ）:

- Mac とスマホに Tailscale を導入し、同じ tailnet にログインする。
  Mac への導入は private ホストで `mise run bootstrap:mac-packages` が行う（`tailscale-app`）。
  `mise bootstrap packages apply brew-cask:tailscale-app` は、pkg インストーラの sudo 要求で
  実機では中断したため使わない。
- 管理画面（https://login.tailscale.com/admin/dns）で MagicDNS と HTTPS Certificates を有効にする。
- Mac は起動したままにする（スリープ中は接続できない）。スマホは Tailscale の VPN をオンにする。

手順（work3 の例。環境が異なる場合は `--sbx` と各ポートを置き換える）:

1. sandbox の公開ポートを確認する。

   ```sh
   mise run t3:cli -- --sbx work3 ports
   ```

2. その公開ポートを、tailnet の HTTPS に出す。HTTPS ポートは 443 / 8443 / 10000 から選び、
   環境ごとに重複しないようにする。この設定は永続し、場所を変えても tailnet のアドレスは変わらない。

   ```sh
   tailscale serve --bg --https=8443 http://127.0.0.1:<公開ポート>
   ```

3. この Mac の MagicDNS 名を確認する。`tailscale status --json` の `Self.DNSName`（末尾の `.` は除く）。

4. スマホ用の pairing token を発行する。

   ```sh
   mise run t3:cli -- --sbx work3 auth pairing create --ttl 10m --label phone \
     --base-url https://<MagicDNS名>:8443
   ```

5. スマホの T3 Code アプリで Add environment を開き、`https://<MagicDNS名>:8443` と Token を入力する。
   `127.0.0.1` はスマホでは PC を指さない。Token は一度使うと無効で、10 分で期限が切れる。
   ブラウザーで Pair URL を開くと Token を使い切るため、アプリに直接入力する。

接続後は、アプリの環境選択だけで使える。再実行が要るのは、Token の期限切れと端末の追加のときだけ。
この経路だけを止める場合は、対応するポートを指定して `tailscale serve --https=8443 off` を実行する。

## 自動起動と保存先

| 項目                        | 保存先（既定）                                                   |
| --------------------------- | ---------------------------------------------------------------- |
| ホスト側 profile            | `~/.local/state/t3-sandbox/profiles/<sandbox-name>.json`         |
| 履歴・設定・worktree・clone | `~/.local/share/t3-sandbox/<sandbox-name>/t3/`                   |
| macOS サービス              | `~/Library/LaunchAgents/local.t3-sandbox.<sandbox-name>.plist`   |
| macOS ログ                  | `~/.local/state/t3-sandbox/logs/<sandbox-name>.log`              |
| Linux サービス              | `~/.config/systemd/user/local.t3-sandbox.<sandbox-name>.service` |

データ領域はそのアカウントの sandbox に追加 mount し、ホスト用 profile は mount の外に置く。
XDG_DATA_HOME / XDG_STATE_HOME / XDG_CONFIG_HOME の指定にも対応。
同じ環境に別 workspace / port を指定して setup を再実行した場合は、既存設定を変更せず停止する。
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
mise run t3:cli -- --sbx account2 ports
mise run t3:cli -- --sbx account2 server-status
```

サービスを止める際は実行中の作業を確認する。
sandbox を停止するだけだとサービスが再試行する。
sandbox を削除した場合はサービス経由ではなく、対象アカウントと同じ workspace を指定して（以下は work3 の例）
`mise run t3:setup -- --sbx work3 --workspace /path/to/project` を実行し、
再作成時の plan を手動で確認・承認する。サービスからの無条件な自動承認は行わない。

### 設定済み sandbox を削除する

対象リポジトリで `mise run t3:reset` を実行し、fzf でアカウントを選んで削除を確認する。
自動起動サービスを解除し、sandbox を停止してから削除する。ホスト側の登録も削除し、公開ポートを解放する。
実行中の作業は中断されるため、sandbox 内だけにある必要なファイルは先に保存する。
ホストに保存された T3 の設定と履歴は残る。
また使う場合は `mise run t3:setup` で環境を作成する。
削除の途中でエラーが出たら、原因を解消して `mise run t3:reset` を再実行する。

### macOS で旧 sandbox の自動起動を解除する

旧 `t3-account1`、`t3-account2`、`t3-work3`、`t3-oauth` は、LaunchAgent の `KeepAlive` により、sandbox を削除しても再作成されることがある。
対象の環境で作業を終えてから、Mac のターミナルで自動起動を無効にし、登録中のジョブを取り除く。
以下は `account1` と `work3` の例。対象に応じてループ内のアカウント一覧を変更する。

```sh
for account in account1 work3; do
  service="gui/$(id -u)/local.t3-sandbox.$account"
  launchctl disable "$service" || continue
  if launchctl print "$service" >/dev/null 2>&1; then
    launchctl bootout "$service" || continue
  fi
done
```

自動起動を解除できたアカウントごとに、`sbx ls` で `t3-<account>` が残っているか確認する。
必要なファイルを保存したら、同じアカウント名を入れて `sbx stop t3-<account>` と `sbx rm t3-<account>` を実行する。
この自動起動解除は旧サービスのラベルだけを対象とする。T3 のホスト側データは
`${XDG_DATA_HOME:-$HOME/.local/share}/t3-sandbox/` 以下に残る。

## 検証と実機確認

mise タスクは初回設定の `t3:setup`、接続・診断用の `t3:cli`、sandbox 削除用の `t3:reset`。
ポート確認・サービス状態・再起動も `t3:cli` のメニューから実行できる。
処理本体は `local/bin/t3-sandbox` の Python スクリプトに置き、
自動起動サービスは mise でツール環境を読み込んでから、このスクリプトを直接呼び出す。

以前のタスク定義から更新する場合は、dotfiles の checkout root へ移動して配置する。

```sh
cd /path/to/dotfiles
mise bootstrap dotfiles apply
```

続いて `mise run t3:cli` で**restart-server** → 設定済みの Sandbox を選ぶ。
設定済みのプロファイルごとに一度実行する。
これで既存サービスの呼び出し先も更新される。実行中の作業は先に終了する。
この作業環境には `sbx` と `/dev/kvm` がないため、**microVM、LaunchAgent / systemd の実起動、
実際の Claude 認証とスマホ接続は未確認**。
実機ではアプリで作った複数スレッドが別 worktree・同一アカウントの sbx を使うこと、
アカウント切替、PC 再ログイン後の再接続を確認する。

参考: [公式 README](https://github.com/pingdotgg/t3code)、
[リモートアクセス](https://github.com/pingdotgg/t3code/blob/main/docs/user/remote-access.md)、
[worktree 設定](https://github.com/pingdotgg/t3code/blob/main/docs/user/project-settings.md)。
