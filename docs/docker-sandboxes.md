# Docker Sandboxes (sbx)

[Docker Sandboxes](https://www.docker.com/products/docker-sandboxes/) は、AI エージェントを
microVM の中で動かすための Docker 製ツールです。CLI は `sbx`。

このリポジトリでは **AI エージェントの実行環境を devcontainer から Docker Sandboxes へ移行**しています。
`multi-worktree dev` の既定バックエンドが sandbox になり、devcontainer は `--devcontainer` で使う
フォールバック経路として残しています。

ツールチェインとホスト連携は devcontainer と同じものを sandbox 側へ移植済みです。
項目ごとの再現状況は [devcontainer との機能対応表](#devcontainer-との機能対応表) を参照してください。

> [!IMPORTANT]
> 使い始める前に **1 回だけ** 次を実行してください。カスタム template を作らないと
> sandbox 内にツールチェイン（mise + lint 群 / nvim / crit / plannotator など）が入りません。
> 普段の開発フローは [ccmanager での開発の段取り](#ccmanager-での開発の段取り) を参照してください。
>
> ```bash
> mise run sandbox:setup           # secret / network policy / skills / SSH 鍵
> mise run sandbox:build-template  # devcontainer と同じツール群入りの template をビルド
> mise run sandbox:mcp-add             # config/sbx/mcp*.yml の MCP をホストの sbx mcp へ登録
> ```

## mise タスク一覧

sandbox 関連の mise タスクです（定義は `tasks/sandbox.toml`）。

| タスク                   | 用途                                                                                                                                              | 使うタイミング               |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| `sandbox:setup`          | ホスト側の初期設定（network policy / secret / skills の import / 通知用 SSH 鍵など）                                                              | 初回だけ                     |
| `sandbox:build-template` | devcontainer と同じツールチェイン入りの template を、fzf で選んだ agent ごとにビルドして sbx へ読み込む（`sbx-agent:<agent>`。claude を選択済み） | 初回・ツール構成を変えたとき |
| `sandbox:mcp-add`        | `config/sbx/mcp*.yml` の MCP をホストの gateway へ登録する（`sbx mcp add`。定義の変更も反映）                                                     | 初回・yml を変えたとき       |
| `sandbox:mcp-load`       | 読み込み済み MCP を全て外してから、fzf で複数選択した登録済み MCP だけを起動中の sandbox へ読み込む（何も選ばなければ全て外すだけ）               | 必要になったとき             |
| `sandbox:template-ls`    | 保存済み template の一覧                                                                                                                          | 随時                         |
| `sandbox:template-rm`    | template を fzf で複数選択して削除する（引数で tag を指定することもできる）                                                                       | 随時                         |
| `sandbox:disk`           | ディスク使用量の内訳を表示する（ホストの Docker / sbx の template / 各 sandbox）。読み取り専用                                                    | 容量が気になったとき         |
| `sandbox:prune`          | ディスクを回収する。既定は dry-run で `--yes` で実行（`--template` / `--build-cache` / `--all` で対象を広げる）                                   | 容量が足りないとき           |

## devcontainer に対する利点

### 隔離境界が強い

devcontainer はコンテナなのでホストと kernel を共有します。sandbox は **microVM** で専用 kernel を
持つため、コンテナ脱出に相当する攻撃面が減ります。エージェントを `--dangerously-skip-permissions` /
`--yolo` で走らせる前提では、この差がそのまま安全余裕になります。

### ファイルシステムの露出が「渡したものだけ」になる

devcontainer の `mounts` は書けば何でも bind mount できるため、`../..` のような指定で
`$HOME` 全体が見えてしまう事故が起きます（実際に main ではその mount をやめています）。
sandbox は **workspace として明示的に渡したディレクトリしか見えません**。
`devcontainer.json` を読まないと露出範囲が分からない devcontainer と違い、
`sbx inspect` / `sbx ls` で現在の mount 範囲をそのまま確認できます。

### ネットワークが既定で制御される

devcontainer はホストのネットワークをそのまま使うため、エージェントの通信先を制限する手段が
ありません。sandbox は**全 HTTP/HTTPS がホスト側プロキシを通り**、network policy
（`open` / `balanced` / `locked down`）で許可先を制御できます。
`sbx policy log` で「何がブロックされたか」を後から追えるので、
エージェントが想定外のホストへ出ようとしたことに気付けます。

### 認証情報をエージェントに渡さずに使える

devcontainer は `GH_TOKEN` を `remoteEnv` で渡し、`~/.config/gh` を mount するため、
**エージェントが生トークンを読めます**。sandbox は `sbx secret` で OS キーチェーンに保存し、
ホスト側プロキシが送信時に注入するため、エージェントはトークンを読めません。

```bash
sbx secret set github --command 'gh auth token'
```

コミット署名も同じ発想で、**SSH agent forwarding が既定で有効**です。devcontainer では
専用の署名鍵を生成してコンテナに mount していましたが、sandbox ではホストの ssh-agent に
署名を依頼するだけなので**秘密鍵がゲストに渡りません**。

### 定義ファイルとビルドが不要

devcontainer は `devcontainer.json` の生成（`multi-worktree` が jq で合成）と Dockerfile の
ビルドが必要で、`mounts` を変えるたびに `initialize.sh` も直す必要がありました。
sandbox は CLI 引数と `[settings.sandbox]` だけで起動し、イメージビルドもありません。
宣言的に書きたい場合は `sbxenv.yaml`（後述）も選べます。

### docker daemon が最初から分離されている

devcontainer では docker-in-docker feature を有効化し、`${devcontainerId}` でスコープした
named volume を `/var/lib/docker` に当てて worktree 間の混線を防ぐ、という作り込みが必要でした。
sandbox は**最初から sandbox 専用の docker daemon** を持つため、この作り込み自体が不要です。

### 起動・破棄が軽い

`sbx run --rm` で使い捨てセッション、`sbx run -d` でバックグラウンド常駐、`sbx stop` で
インストール済みパッケージを保ったまま停止できます。`sbx prune` でまとめて掃除もできます。

ここで言う「軽い」は**手順**の話（定義ファイルもビルドも要らない）で、**消費資源は
devcontainer の方が有利**です。後述の「[リソース使用量](#リソース使用量devcontainer-との比較)」
を参照してください。

### 比較表

| 項目           | devcontainer                            | Docker Sandboxes (sbx)                                        |
| -------------- | --------------------------------------- | ------------------------------------------------------------- |
| 隔離境界       | コンテナ（ホストと kernel 共有）        | microVM（専用 kernel）                                        |
| 起動方法       | `devcontainer up` + `devcontainer exec` | `sbx create` + `sbx run`                                      |
| ホスト連携     | `mounts` で任意のパスを bind mount      | workspace として渡したディレクトリのみ                        |
| マウント先パス | `devcontainer.json` の `target` で指定  | **ホストと同じ絶対パス**に固定                                |
| docker 利用    | docker-in-docker feature を有効化       | 標準で sandbox 専用 docker daemon を持つ                      |
| ポート公開     | `appPort` / `forwardPorts`              | `--publish` / `sbx ports`                                     |
| 通信制御       | 無し（ホストのネットワークに準拠）      | ホスト側プロキシで network policy を強制                      |
| 認証情報       | `~/.config/gh` などを read-only mount   | `sbx secret` で OS キーチェーンに保存し、プロキシが注入       |
| コミット署名   | 専用 SSH 鍵をコンテナに mount           | ssh-agent forwarding（秘密鍵はホストに残る）                  |
| ツールチェイン | Dockerfile + mise で固定・キャッシュ    | カスタム template（同じ `mise.toml` を使う）                  |
| 定義ファイル   | `config/devcontainer/devcontainer.json` | 不要（CLI 引数と `[settings.sandbox]`、任意で `sbxenv.yaml`） |
| リソース消費   | 1 つの VM を全コンテナで共有（有利）    | sandbox ごとに VM + 専用 daemon（下記「リソース使用量」参照） |

## 大きな前提の違い

1. **sandbox が見られるのは workspace として渡したディレクトリだけ。** `~/.claude/settings.json` の
   ようなユーザーレベル設定は、追加 workspace として渡さない限り sandbox 内から見えません。
2. **sandbox 内の `$HOME` はホストと別物。** 同じ絶対パスにマウントされるので、
   `~/.config/git/config` を渡しても git は自動では読みません。環境変数で明示する必要があります
   （`sbx-agent` が自動で行います）。
3. **workspace・ports・secrets・`sandboxOptions` は作成時にしか確定しない。**
   変更するには `sbx rm` して作り直します（`sbx mount` / `sbx umount` で後から足せる
   dynamic mount もありますが、`sbx-agent` は使っていません）。

## リソース使用量（devcontainer との比較）

**結論から言うと、リソース効率は devcontainer の方が有利です。** sbx はそれを隔離の対価として
払っています。Docker 公式の Architecture ページがそのまま書いています。

> Sandboxes trade higher resource overhead (a VM plus its own daemon) for complete isolation.
> — [Architecture](https://docs.docker.com/ai/sandboxes/architecture/)

差が出るのは **並列数** です。1 つだけ長時間動かすなら体感差は小さく、`multi-worktree` で
複数同時に動かすほど開きます。

### 構造の違い

| 観点             | devcontainer（Docker Desktop）                                 | sbx（ローカル sandbox）                                                              |
| ---------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| 分離単位         | **1 つの Linux VM を全コンテナで共有**（kernel 共有）          | **sandbox ごとに microVM**（専用 kernel）                                            |
| メモリ既定       | Docker VM に対してホストの 50%（1 つ分）                       | **sandbox ごとに**ホストの 50%（512 MiB〜32 GiB、上限 `max(75%, 512 MiB)`）          |
| swap             | 1 GB（既定）                                                   | 設定項目が見当たらない（未確認）                                                     |
| CPU 既定         | Docker Desktop の CPU limit（1 つ分）                          | `--cpus` 未指定で**ホストの全 CPU**（Linux arm64 のみ 16 上限）                      |
| ディスク         | 1 つの disk image を共有し、**image layer も全コンテナで共有** | sandbox ごとに root 20 GB + docker data 10 GB。**layer は sandbox 間で共有されない** |
| アイドル時の回収 | Resource Saver が既定 5 分で VM を停止し **2 GB 以上**を返す   | **ローカルには idle 停止が無い**（`--ttl` / `--on-timeout` は cloud 限定）           |
| 復帰コスト       | VM 再起動 3〜10 秒                                             | `sbx stop` したものは `sbx run` で再開（VM の再作成は不要）                          |
| ホスト FS 経由   | virtiofs の bind mount                                         | virtiofs passthrough（ホスト側キャッシュが既定 ON）                                  |
| docker daemon    | 1 つ（docker-in-docker を足すとコンテナ内にもう 1 つ）         | **sandbox ごとに 1 つ**                                                              |

効いてくるのは主に次の 3 点です。

1. **メモリの既定が「ホストの 50%」で、それが sandbox ごとに付く。**
   Docker Desktop の Memory limit も既定はホストの 50% ですが、そちらは VM 1 つ分です。
   sbx は 2 つ起動すれば 50% の上限が 2 つ並びます（上限なので常時その量を使うわけでは
   ありませんが、設計上の天井が違います）。
2. **CPU の既定が「全部」。** `cpus: 0`（= `--cpus` 未指定）はホストの全 CPU を割り当てます。
   並列で起動すると素直にオーバーサブスクライブします。実際これが問題になった形跡があり、
   Linux arm64 では「複数の sandbox を同時起動すると `VM did not connect within 15s` で
   失敗する」ため既定が 16 CPU に制限されています（[Release notes](https://docs.docker.com/ai/sandboxes/release-notes/)）。
3. **image layer が sandbox 間で共有されない。** devcontainer なら同じ base image を
   N 個のコンテナが共有しますが、sandbox はそれぞれが自分の image store を持ちます。
   このリポジトリの template はツールチェイン一式で数 GB あるため、ここが一番効きます。

### 数値の出所

| 数値                                                      | 出所                                                                                                                             |
| --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| 「VM + 専用 daemon の分だけオーバーヘッドが高い」         | [Architecture](https://docs.docker.com/ai/sandboxes/architecture/)（公式明記）                                                   |
| 「sandbox 間で image / layer を共有しない」               | 同上（"Multiple sandboxes don't share images or layers."）                                                                       |
| sandbox ごとに専用 kernel                                 | [Isolation layers](https://docs.docker.com/ai/sandboxes/security/isolation/)                                                     |
| メモリ既定 50% / 512 MiB〜32 GiB / 上限 max(75%, 512 MiB) | `sbx create --help`（sbx 0.47.0 の実バイナリで確認）                                                                             |
| `cpus: 0` = 全 CPU、Linux arm64 は 16 上限                | [Environment files](https://docs.docker.com/ai/sandboxes/configuration/environment-files/)                                       |
| root 20 GB / docker data 10 GB（既定）                    | [Troubleshooting](https://docs.docker.com/ai/sandboxes/troubleshooting/)（`DOCKER_SANDBOXES_ROOT_SIZE` / `_DOCKER_SIZE` で変更） |
| Docker Desktop の Memory limit 既定 50% / swap 1 GB       | [Docker Desktop settings](https://docs.docker.com/desktop/settings-and-maintenance/settings/)                                    |
| Resource Saver で 2 GB 以上回収・既定 5 分・復帰 3〜10 秒 | [Resource Saver mode](https://docs.docker.com/desktop/use-desktop/resource-saver/)                                               |
| virtiofs キャッシュが既定 ON                              | [Architecture](https://docs.docker.com/ai/sandboxes/architecture/)                                                               |

### 分かっていないこと

- **Docker は sandbox 1 つあたりの実測オーバーヘッドを公開していません。**
  探した範囲では見つからず、出てくるのは個人ブログの観測値だけでした
  （例: 36 GB のホストで既定 17.8 GB が割り当てられた、という観測）。数値として引くには弱いので、
  必要なら下の手順で自分の環境を測るのが確実です。
- **割り当てたメモリが常時 RSS として居座るのかは未計測。** sbx の VMM（`libsailor.so`）には
  `virtio_balloon` と `BalloonStats` のシンボルがあるので、ballooning で返す仕組みはあり、
  `--memory` は「上限」であって予約ではない可能性が高いと見ています（シンボルの存在のみ確認。
  実際に返しているかは未測定）。
- **root 20 GB / docker 10 GB が sparse かどうかも未計測。** 配布物に `mkfs.ext4` が含まれており
  通常は sparse になるため「上限」と読めますが、確認はしていません。
- 参考値として、別実装の microVM では **VMM 自体のメモリオーバーヘッドは小さい**ことが
  仕様として保証されています（Firecracker は 1 vCPU / 128 MiB 構成で VMM スレッドが
  **5 MiB 以下**、`/sbin/init` 到達まで **125 ms 以下**。
  [SPECIFICATION.md](https://github.com/firecracker-microvm/firecracker/blob/main/SPECIFICATION.md)）。
  sbx の VMM は Firecracker ではなく Docker 独自（`containerd-shim-nerdbox` + `libsailor.so`）なので
  **そのまま当てはめられません**が、「重いのは VMM プロセスではなく guest kernel と
  guest 側のページキャッシュ」という見方の裏付けにはなります。

### 自分の環境で測る

```bash
# sandbox ごとに記録された CPU / memory の上限を見る
sbx ls --json

# TUI でライブのメモリ・CPU 使用量を見る（カードごとに表示される）
sbx

# devcontainer 側
docker stats                 # コンテナごとの CPU / メモリ
docker system df             # image / layer / volume の実使用量
```

Docker Desktop 側の総量は Settings > Resources（Memory limit / Disk usage limit）と
Settings > Resources > Advanced の Disk usage で見られます。

### このリポジトリでの実務的な指針

- **並列させるなら上限を明示する。** `sbx-agent` は `--cpus` / `--memory` をそのまま渡すので、
  `multi-worktree` で複数動かすときは既定（全 CPU・ホストの 50%）に任せず絞るのが無難です。
- **使い終わったら止める。** ローカル sandbox には idle 停止が無いので、`sbx stop` で止めるか
  `sbx run --rm` で使い捨てにします。溜まったものは `sbx prune`（停止済みを一括削除）や
  `sbx rm` で片付けます。ディスクは sandbox 単位で増えるので、ここが一番効きます。
  現状確認は `mise run sandbox:disk`、回収は `mise run sandbox:prune`
  （[ディスクを空ける](#ディスクを空けるimage-layer-の-prune)参照）。
- **ディスクが厳しいなら devcontainer を使う。** `multi-worktree dev --devcontainer` で
  従来経路に戻せます。隔離より資源効率を優先する場面では素直にこちらです。
- **同じタスク内で Claude のセッションを増やすだけなら sandbox を増やさない。** sandbox の中で
  `←` / `/bg` / `claude agents` を使えば VM は 1 つのままです（この構成は未検証。
  [`docs/ai.md`](ai.md#sandbox-ごとに起動する場合との比較)）。

## セットアップ

Docker Desktop は不要です。`sbx` は mise で管理しています（mac 専用。microVM が
Apple Silicon / Windows 11 のみ対応のため）。

```bash
# config-mac/mise/config.mac.toml の [tools] に以下が入っている
#   "github:docker/sbx-releases" = { version = "0.48.0", asset_pattern = "DockerSandboxes-darwin.tar.gz", bin_path = "bin" }
mise install
sbx version
```

aqua registry には `sbx` が未登録のため、github backend で
[docker/sbx-releases](https://github.com/docker/sbx-releases) のリリース資産を直接取得しています。
バージョンは renovate が追従します。

> [!NOTE]
> Windows(WSL2) では `sbx` を導入していません。microVM は Windows ホスト側の
> Hypervisor Platform を使うため、WSL2 の中からは利用できません。

Docker ID でサインインします。

```bash
sbx login
```

初回実行時に既定の network policy を聞かれます。AI API・npm・pip・GitHub・レジストリが
許可される `Balanced` を選んでおくのが無難です。プロンプトを出さずに設定する場合:

```bash
sbx policy set-default balanced
```

GitHub トークンは secret として登録しておきます。ホストの `gh` から都度解決され、
送信時にホスト側プロキシが注入するので、**生トークンはエージェントから読めません**。

sandbox には `~/.config/gh` をマウントしません。`gh` が OS のキーチェーンを使えない環境だと
`hosts.yml` にトークンが平文で保存され、read-only マウントでもエージェントから読めてしまうためです。
sandbox 内の `gh` と git の GitHub 認証はこの secret 経由で通ります。

```bash
sbx secret set github --command 'gh auth token'
sbx secret ls
```

ここまでと、ホストへの SSH 経路に必要な network policy・skills の取り込み（`~/.claude/skills` /
`~/.agents/skills` / `~/.copilot/skills` を走査）・通知用 SSH 鍵の生成・ドキュメントサイトの許可
（[後述](#ドキュメントサイトの許可)）・ホスト設定（`clipboard.imagePaste`）は 1 つの task にまとめてあります。

```bash
mise run sandbox:setup
```

### コミット署名用の SSH 鍵を ssh-agent に登録する（Mac で一度だけ）

sandbox 内のコミットは、ホストの ssh-agent を forwarding して SSH 署名します
（[詳細](#ホストの-git-設定とコミット署名)）。ホストの ssh-agent が空だと `sbx-agent` が
`ホストの ssh-agent に鍵が無いため sandbox 内のコミット署名を無効化します` と警告し、
署名なしでコミットされます。次を一度だけ実行してください。

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
ssh-add -L   # 公開鍵が 1 行出れば OK
```

- 再起動で agent が空になっても、`sbx-agent` が起動時に署名用の鍵を自動で agent に読み込み直します
  （パスフレーズ無しの鍵はそのまま、パスフレーズ付きの鍵は `--apple-use-keychain` で Keychain に
  保存したパスフレーズを使います）。手で `ssh-add` し直す必要はありません。
- 署名に使うのは常に `~/.ssh/id_ed25519`（`SBX_AGENT_SIGNING_KEY` で変更可）です。agent に他の鍵が
  先に入っていても、GitHub に登録済みの同じ鍵で署名するので、再起動のたびに Unverified になって
  `gh ssh-key add` し直すことはありません。
- このあと `sbx-agent` を起動し直せば警告は消え、sandbox 内のコミットが SSH 署名されます。
- 署名を GitHub で **Verified** にするには、同じ公開鍵（`ssh-add -L` の出力）を
  GitHub の [SSH and GPG keys](https://github.com/settings/keys) に **Signing key** として
  登録してください。Authentication key とは別の枠なので、認証用に登録済みでも改めて追加が必要です。
  `gh` からなら次の通りです（登録するのは `.pub` の公開鍵で、秘密鍵は渡しません）。

```bash
# signing key の登録には admin:ssh_signing_key scope が要る（初回だけブラウザで認可）
gh auth refresh -h github.com -s admin:ssh_signing_key
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "sbx signing ($(hostname -s))"
gh ssh-key list   # TYPE が signing の行があれば OK
```

> [!NOTE]
> このうち **github の secret 登録と `localhost:22` の policy 許可は、`sbx-agent` が sandbox を
> 作るときに自動でも実行**します。github の secret は毎回ホストの `gh` から登録し直すので、
> `gh auth refresh` などでトークンが入れ替わっても、sandbox を作り直せば追従します。
> ドキュメントサイトの許可とホスト設定は `sandbox:setup` でだけ反映するため、
> `config/sbx/allow-domains*.txt` を変更したら `mise run sandbox:setup` を再実行してください。

### ドキュメントサイトの許可

`Balanced` の allowlist には AI API・パッケージレジストリ・GitHub などが入っていますが、
docs.anthropic.com・MDN・Zenn・Qiita・Stack Overflow のような**ドキュメント・技術情報サイトは
入っていません**。調査中に毎回ブロックされないよう、よく読むサイトを
`config/sbx/allow-domains.txt`（1 行 1 パターン、`#` 以降はコメント）に並べ、
`sandbox:setup` が `sbx policy allow network` で全 sandbox に許可します。

- 特定の環境（work3 / private など）でだけ許可したいドメインは `config/sbx/allow-domains.<name>.txt` に
  書きます。gitignore 済みなのでコミットされず、`sandbox:setup` が `allow-domains.txt` と一緒に読み込みます。
  雛形の `allow-domains.work3.txt.example` を `.example` を外してコピーして使ってください。
- 一覧に無いドメインは、ブロック時に出る承認リクエストで個別に許可します
  （`sbx policy approval ls` → `sbx policy approval respond <id> --option <option-id>`）。
- preset を `allow-all` にすれば許可の手間は無くなりますが、プロキシが GitHub トークンなどを
  注入している以上、外部への持ち出しを防ぐ効果が失われるため `Balanced` のまま必要な分だけ許可します。
- kit の `permissions.network.allow` でも宣言できますが採用していません。kit は sandbox 作成時にしか
  反映されず、許可を足すたびに sandbox の作り直しが必要になるためです。global な policy なら
  起動中の sandbox にも即座に反映されます。
- 一覧から行を消しても反映済みのルールは残ります。`sbx policy rm network --resource <domain>` で
  個別に削除してください。

続いて、devcontainer と同じツールチェインが入った template をビルドします
（[後述](#ツールチェインカスタム-template)）。これをやらないと sandbox 内に lint 群や crit が入りません。

```bash
mise run sandbox:build-template
```

ホストの sshd 側の準備（`authorized_keys` への登録・リモートログインの有効化・通知の表示許可）は
devcontainer と共通です。[docs/devcontainer.md](./devcontainer.md) の手順に従ってください。

## 基本操作

```bash
# ── ライフサイクル ─────────────────────────────────────────────
sbx create --name=my-sbx claude .    # 作成のみ（アタッチしない）
sbx run --name=my-sbx claude .       # 作成してアタッチ
sbx run --name=my-sbx                # 既存 sandbox に再アタッチ（agent は spec から解決）
sbx run --name=my-sbx --branch=fix-bug # branch mode（専用 worktree で作業させる）
sbx run --name=my-sbx -- --continue  # `--` 以降は agent へ pass-through
sbx run --rm claude                  # セッション終了時に sandbox を削除
sbx run -d --name=my-sbx claude .    # バックグラウンド常駐（ポート公開したまま使う）
sbx ls                               # 一覧
sbx inspect my-sbx                   # mount・リソース・ポートを確認
sbx stop my-sbx                      # 停止（インストール済みパッケージは保持）
sbx rm my-sbx                        # 削除（VM と .sbx/ 配下の worktree も消える）
sbx prune                            # 使っていない sandbox をまとめて削除

# ── シェル・デバッグ ───────────────────────────────────────────
sbx exec -it my-sbx bash             # sandbox 内でシェルを開く（ホスト側の端末から）
sbx exec my-sbx bash -c "cmd"        # 単発コマンド（-d / --detach は非対応）
sbx cp ./a.json my-sbx:/path/        # ファイル転送

# ── ポートフォワード ───────────────────────────────────────────
sbx ports my-sbx --publish 8080:8000
sbx ports my-sbx                     # 現在の公開ポート一覧
sbx ports my-sbx --unpublish 8080:8000

# ── network policy ─────────────────────────────────────────────
sbx policy ls
sbx policy log my-sbx                # 何がブロックされたかを確認
sbx policy allow network "*.npmjs.org,*.pypi.org"

# ── 認証情報 / skills / MCP ────────────────────────────────────
sbx secret set github --command 'gh auth token'
sbx skills import --force            # ホストの skills を共有 store へ取り込む（確認を飛ばす）
sbx mcp add <name> --url <url>       # MCP サーバを gateway 経由で共有

# ── TUI ────────────────────────────────────────────────────────
sbx                                  # ダッシュボード（c:作成 / Enter:アタッチ / x:シェル / r:削除）
```

追加 workspace は `sbx run <agent> <primary> <extra>...` の形で渡します。
`:ro` を付けると read-only になり、単一ファイルも指定できます。

```bash
sbx run --name=my-sbx claude ~/dev/app ~/dev/libs:ro ~/.config/git/config:ro
```

## このリポジトリでの使い方

### `sbx-agent` ラッパー

`local/bin/sbx-agent`（適用後: `~/.local/bin/sbx-agent`）が **sbx 呼び出しの単一実装**です。
ccmanager のプリセットと `multi-worktree dev` の両方がこれを経由します。

```bash
sbx-agent claude                              # カレントディレクトリを workspace に起動
sbx-agent codex -- resume --yolo              # agent に引数を pass-through
sbx-agent claude --config-dir ~/.claude-work3 --name-prefix w3
sbx-agent claude --branch=auto                # branch mode
sbx-agent claude --rm                         # セッション終了時に削除
sbx-agent claude --skills=off                 # 共有 skills を渡さない
sbx-agent claude --publish 7842:7842          # ポート公開
sbx-agent claude --mount ~/dev/libs:ro        # 追加 workspace
sbx-agent --help
```

やっていること:

1. sandbox 名を `<repo>-[<prefix>-]<branch>-<agent>` から生成する
   （hostname 相当なので英数字とハイフンに正規化し、63 文字に切り詰める）
2. 同名の sandbox が無ければ `sbx create` で作成する。このとき
   `~/.config/git/config:ro` / `~/.config/git/gitignore:ro` / `~/.aws/config:ro` /
   `~/.agents:ro` / `~/.config/nvim:ro` / `~/.ssh/known_hosts:ro` / `~/.claude.json:ro` /
   `~/.local/share/agent-lessons`（書き込み可）と agent の設定ディレクトリを追加 workspace として渡す（`devcontainer.json` の `mounts` に対応）。
   マウントは作成時にしか付かないため、追加したマウントを既存の sandbox に反映するには `sbx-agent <agent> --new` で作り直す
   `~/.config/gh` はトークンが平文で入りうるため渡さない（`sbx secret` 経由にする）
3. workspace が linked worktree なら、その common git dir（実体リポジトリの `.git`）も
   追加 workspace として渡す（[後述](#worktree-と-git-metadata-の-mount)）
4. `--env` で devcontainer の `remoteEnv` 相当（`AI_AGENT` / `TERM` / `HOST_USER` /
   `LEFTHOOK_CONFIG` / `INSTALL_LOCAL_LEFTHOOK` / `MISE_TRUSTED_CONFIG_PATHS`）と agent の設定ディレクトリ
   （`CLAUDE_CONFIG_DIR` / `CODEX_HOME`）を渡す
5. 同じく `--env` で `GIT_CONFIG_COUNT` / `GIT_CONFIG_KEY_n` / `GIT_CONFIG_VALUE_n` を渡し、
   ホストの git 設定とコミット署名を設定する（[後述](#ホストの-git-設定とコミット署名)）
6. `sbx run --name <name>` でアタッチする（位置引数で名前を渡す形は sbx 0.47 で deprecated）

agent ごとの設定ディレクトリの対応（`--config-dir` で上書き可）:

| agent   | 設定ディレクトリ | sandbox 内で参照させる環境変数 |
| ------- | ---------------- | ------------------------------ |
| claude  | `~/.claude`      | `CLAUDE_CONFIG_DIR`            |
| codex   | `~/.codex`       | `CODEX_HOME`                   |
| copilot | `~/.copilot`     | （マウントのみ）               |

`SBX_AGENT_MOUNTS` に `,` 区切りでパスを並べると、追加 workspace をまとめて指定できます
（`:` は read-only 指定の `:ro` と衝突するため区切り文字は `,`）。

### `multi-worktree dev`

`multi-worktree dev` の既定バックエンドが Docker Sandboxes です。
task root（全リポジトリの worktree をまとめた親ディレクトリ）が primary workspace になり、
`sbx-agent` に委譲します。

```bash
multi-worktree dev feat/add-auth                      # 既定 agent を sandbox で起動
multi-worktree dev feat/add-auth claude               # agent を指定
multi-worktree dev feat/add-auth codex -- --continue  # agent に引数を pass-through
multi-worktree dev feat/add-auth claude --branch=auto # branch mode
multi-worktree dev feat/add-auth --new                # sandbox を削除して作り直す
multi-worktree dev feat/add-auth --rm                 # 終了時に sandbox を削除
multi-worktree dev feat/add-auth --name=my-sbx        # sandbox 名を明示
multi-worktree dev feat/add-auth --devcontainer ccmanager  # devcontainer backend
```

設定は `~/.config/multi-worktree/config.toml` の `[settings.sandbox]` で行います。

```toml
[settings.sandbox]
# dev サブコマンドの既定バックエンド（"sbx" | "devcontainer"）
backend = "sbx"
# agent 名を省略したときに起動する agent
default_agent = "claude"
# sandbox 名の接頭辞（sandbox 名は <prefix>-<task>-<agent>）
name_prefix = "mw"
# 共有 skills store の扱い（off | readonly | readwrite）
skills = "readonly"
# sandbox template の OCI 参照（空なら sbx-agent の既定 = agent ごとの sbx-agent:<agent>）
# 設定すると全 agent で同じ template になるため、agent と FLAVOR が合わないと kit が適用されず、作成失敗またはログインを求められる
# template = "sbx-agent:claude"
# リソース上限
# cpus = "4"
# memory = "8g"
# 公開ポート（host:sandbox）
# publish_ports = ["7842:7842"]
# task root に加えてマウントする workspace（sbx-agent の既定分は書かなくてよい）
extra_workspaces = ["~/.coderabbit"]
```

`backend = "devcontainer"` にすると従来どおり `devcontainer up` / `devcontainer exec` が既定になります。

### ccmanager

`config/ccmanager/config.json` の `commandPresets` に、通常 preset と 1:1 対応する
sandbox preset を用意しています。claude は account ごとに別 sandbox になります
（env は作成時に固定されるため、`--name-prefix` で branch 名の前に account の識別子
（`a1` / `a2` / `w3`）を入れて名前を分けています）。

| preset id      | 起動内容                                                            |
| -------------- | ------------------------------------------------------------------- |
| `sbx`          | `sbx-agent claude --claude-account account1 --name-prefix a1`（`~/.claude`）                  |
| `sbx-account2` | `sbx-agent claude --config-dir ~/.claude-account2 --claude-account account2 --name-prefix a2` |
| `sbx-work3`    | `sbx-agent claude --config-dir ~/.claude-work3 --claude-account work3 --name-prefix w3`    |
| `sbx-codex`    | `sbx-agent codex -- resume --yolo`                                  |
| `sbx-copilot`  | `sbx-agent copilot -- --resume --yolo`                              |

実際の preset は上の表のコマンドを直接 `command` に書くのではなく、
`command: "zsh"` + `args: ["-c", "exec sbx-agent … -- \"$@\"", "sbx-agent"]` の形にしています。
理由は2つあり、どちらも省略できません。

- **PATH**: ccmanager は親プロセスの環境でそのまま `command` を exec するため、GUI から
  起動した ccmanager では `~/.local/bin` が PATH に無く `sbx-agent` が見つからない。
  `zsh` は `-c`（非ログイン・非対話）でも `~/.zshenv` を読むので、そこで組み立てている
  PATH（`~/.local/bin`・mise shims）がそのまま効く。
- **引数の転送**: ccmanager は起動時に入力した初期プロンプトを preset の `args` の後ろへ
  足す（`detectionStrategy` ごとに渡し方が違い、`claude`/`codex` は最終引数、
  `github-copilot` は `-i <prompt>`。pin している ccmanager 4.1.25 の
  `dist/utils/presetPrompt.js` の `preparePresetLaunch` で確認）。`zsh -c 'cmd' …` の
  第1引数は `$0` になるため、ダミーの `$0`（`"sbx-agent"`）を置いて以降を `"$@"` で
  受け、`--` の後ろに転送している。これが無いとプロンプトが `$0` に吸われて消える。
  なお `--teammate-mode in-process` の自動注入は `command` が `claude` そのものの
  ときだけなので（同 4.1.25 の `dist/utils/commandArgs.js` の `injectTeammateMode`）、
  `zsh` 経由のこれらの preset には付かない（`sh` 経由の既存 preset「Claude account2」
  「Claude Work3」も同様）。

### Claude サブスクを account ごとに固定する kit（実験的）

ccmanager の Claude Docker Sandbox preset は `--claude-account` を使います。
**設定ディレクトリと sandbox 名を分けるだけでは OAuth アカウントは分かれません。**
標準 Claude agent の `/login` はホスト側の共通認証を更新します。
このため専用の v2 kit [`config/sbx/claude-subscription/spec.yaml`](../config/sbx/claude-subscription/spec.yaml)
を使用し、sandbox 固有の secret を `Authorization: Bearer` として送ります。
API キーの登録インターフェースを使いますが、登録するのは `claude setup-token` の
サブスク用 token です。API キー課金への切り替えを意図したものではありません。

これは [公式 issue #144 の回避策](https://github.com/docker/sbx-releases/issues/144#issuecomment-6372651627)
に基づきます。報告された動作環境は sbx v0.45.1、global anthropic secret なしです。
このリポジトリでは実 sbx による認証検証は未実施です。更新後の sbx での互換性や
サブスクの全機能を保証するものではありません。まず専用の検証 sandbox で確認してください。

#### 1. ホストで token を登録する

ホストの対話端末で次を実行します（Python 3 と Claude CLI が必要です）。

```bash
# account1 → account2 → work3 の順に確認して登録
sbx-claude-setup
```

各アカウントの `claude setup-token` を実行する直前に y/n を確認します。
`y` で実行、`n` または Enter でスキップします。ブラウザでのログイン・アカウント選択は手動です。
成功時は出力から token を抽出し、対応ファイルへ権限 600 で自動保存します。
既存ファイルは成功時だけ置き換え、失敗・中断・token を一意に抽出できない場合は保存しません。
CLI の出力形式に依存するため、形式変更時は抽出に失敗する場合があります。
CLI が表示する token は端末にも表示されますが、端末ログのファイルは作りません。

アカウントごとに実行する場合も、それぞれ y/n 確認が入ります。

```bash
sbx-claude-setup account1
sbx-claude-setup account2
sbx-claude-setup work3
```

| アカウント | 使用する設定 | 自動保存先 |
| --- | --- | --- |
| account1 | `~/.claude` | `~/.local/state/sbx-agent-credentials/account1.token` |
| account2 | `~/.claude-account2` | `~/.local/state/sbx-agent-credentials/account2.token` |
| work3 | `~/.claude-work3` | `~/.local/state/sbx-agent-credentials/work3.token` |

コマンドがまだ PATH にない場合は dotfiles root で `python3 local/bin/sbx-claude-setup` を実行できます。
token の生成と保存を自動化するコマンドで、共通 secret の削除や sandbox の作り直しは行いません。

この保存先は dotfiles の管理対象にも
通常の sandbox mount にも含めません。`sbx-agent` はファイルの所有者・権限・形式を検証し、
stdin 経由で毎回 sandbox 固有 secret に登録します。token はホスト上では平文なので、
バックアップ・同期対象からも外してください。sandbox には本物の token ではなく sentinel が渡ります。
token の期限切れや失効時は `sbx-claude-setup <account>` を再実行し、preset から起動し直します。

#### 2. 共通認証と競合する設定を解消する

```bash
sbx version
sbx secret ls
```

`(global) anthropic` があればラッパーは停止します。他の sandbox への影響を確認し、
必要なアカウントの token を上で準備してから、**手動で**共通 secret を解除します。

```bash
sbx secret rm anthropic --force
```

ラッパーが自動で共通認証を削除することはありません。この方式の sandbox では
`/login` を使わないでください。共通認証が再作成されると、この方式で次回起動できなくなります。
すでに稼働している sandbox の通信はラッパーでは監視できないため、認証設定を変える際は
関連セッションを終了してからやり直してください。

専用 kit は、親 image が生成した `/home/agent/.claude/settings.json` の `apiKeyHelper`
を削除します。ホストの共有設定は編集しません。`--config-dir` の `settings.json` に
`apiKeyHelper` や認証を上書きする env があればラッパーが停止します。
プロジェクトの `.claude/settings*.json` や追加の CLI 引数にも認証の上書きを置かないでください。

#### 3. kit の認証利用を許可して起動する

カスタム kit は組み込み agent と異なり、credential binding の承認が必要です。
**初回だけホストの対話端末で承認すれば、以降の ccmanager 起動では同じ承認を毎回求めません。**
`anthropic` / `api.anthropic.com` の承認はホストの `~/.config/sbx/credentials.yaml` に保存され、
同じ service・認証方式・domain を使う別アカウントや新しい sandbox でも使えます。
アカウントごとの token と sandbox の対応は別に管理するので、この承認によって token が共通化されることはありません。

初回は下の検証コマンドをホストの対話端末で実行し、利用を承認してください。
ccmanager から先に起動すると、未承認でも sbx が作成を続け、認証だけ withheld にする場合があります。
その場合は対話端末で承認してから sandbox を作り直すか、次の binding をホストに事前設定します。
既存の `bindings` と `anthropic` の内容を保ってマージしてください（token は書きません）。

```yaml
bindings:
  anthropic:
    apiKey:
      domains: [api.anthropic.com]
```

```bash
# 最初は旧 sandbox と異なる名前で検証する（各 Claude を終了してから次を実行）
sbx-agent claude --claude-account account1 \
  --config-dir "$HOME/.claude" --name subscription-account1-check
sbx-agent claude --claude-account account2 \
  --config-dir "$HOME/.claude-account2" --name subscription-account2-check
sbx-agent claude --claude-account work3 \
  --config-dir "$HOME/.claude-work3" --name subscription-work3-check
```

`--claude-account` 指定時は組み込み `claude` の代わりに kit のパスを `sbx create` に渡します。
ツール入り template・workspace・設定 mount・初期化処理は従来どおり併用します。
`--no-config` は併用できません。token の保存先を含むディレクトリを workspace / mount に
指定すると、本物の token が sandbox に見えるため起動を止めます。

ccmanager の既存 a1 / a2 / w3 sandbox は組み込み Claude agent なので、そのままは再利用しません。
初回の旧 sandbox は「kit/account を確認できない」として停止します。
必要な sandbox 内のデータを保存し、同じ preset と同じ workspace で使うコマンドに
`--new` を付けて作り直してください。`--new` は旧 sandbox を削除します。
以降は ccmanager の preset を選ぶだけです。削除・再作成で scoped secret が失われても
ラッパーが起動時に再登録します。

```bash
# 対象 workspace で実行。各コマンドは対応する旧 sandbox を削除する
sbx-agent claude --claude-account account1 \
  --config-dir "$HOME/.claude" --name-prefix a1 --new
sbx-agent claude --claude-account account2 \
  --config-dir "$HOME/.claude-account2" --name-prefix a2 --new
sbx-agent claude --claude-account work3 \
  --config-dir "$HOME/.claude-work3" --name-prefix w3 --new
```

承認後は ccmanager の preset から起動できます。ラッパーによる token 再登録は stdin 経由なので、
通常の token 入力は不要です。`sbx env` の plan / host lifecycle 承認は使用していません。
ここでいう非対話は「起動時の認証・承認操作が不要」という意味で、Claude の TUI 自体は通常どおり対話で使います。

以下の場合はホスト側での対応が再び必要です。

- kit の service・認証方式・domain を増やした、または binding を削除した場合: 再承認
- token の期限切れ・失効: ホストで再生成して対応ファイルを更新
- `sbx login` の Docker ログイン切れ、OS キーチェーンのロック: ホストで再認証・解除
- 旧 kit の sandbox からの移行: 必要なデータを保存して再作成

実 sbx での起動検証は未実施のため、初回セットアップ時に一度終了して ccmanager から再起動し、
認証入力なしで使えることを確認してください。

#### 4. 実際の認証先と statusline の表示を確認する

この方式では `/status` や Claude への「アカウントを教えて」という質問から、プロキシが使う
メールアドレスを確定できません。`oauthAccount.emailAddress` はローカル設定に残る情報で、
`setup-token` と sandbox 専用 secret の更新には連動しません。

ラッパーは起動時に `SBX_CLAUDE_ACCOUNT` を渡します。statusline はこの環境で古いメールを
表示せず、初回の推論応答から取得した組織 ID を `account1 org:<organization-id>` と表示します。
account1 は選択した preset の識別子、組織 ID は実際の応答で観測した値です。
組織 ID が取れない場合は `account1 [sbx: 組織ID未取得]` と表示します。通常のホスト起動は従来の
メール表示のままです。反映には Claude を終了して preset から起動し直してください。

`sbx-agent` はアカウントごと・token ごとに初回だけ、sandbox 経由で `max_tokens=1` の
推論リクエストを１回送り、組織 ID を取得します。少量の利用枠を消費し、認証方式によっては課金されます。
本物の token や生成内容は出力しません。

結果はホストの `~/.local/state/sbx-agent-credentials/organizations/<account>.json` に保存します。
statusline は起動時に渡された保存値だけを読み、ネットワーク通信は行いません。
同じ token では別 sandbox・再起動でも再取得しません。token が変わった場合は古い ID を使わず、
新しい token の初回だけ取得します。取得失敗・ヘッダー未返却時も試行を記録し、自動再試行しません。
同時起動はアカウントごとのロックで二重取得を防ぎます。

ホストで保存値を確認するには次を実行します。すでに取得を試みた token では追加リクエストを送りません。

```bash
sbx-claude-auth-check dotfiles-a1-main-claude
sbx-claude-auth-check dotfiles-a2-main-claude
sbx-claude-auth-check dotfiles-w3-main-claude
```

モデル非対応や一時エラーを解消して、明示的に再取得する場合だけ `--refresh` を指定します。
この場合は追加で１回リクエストを送ります。実行後は Claude を終了して preset から再起動すると表示に反映されます。

```bash
sbx-claude-auth-check dotfiles-a1-main-claude --refresh
```

`HTTP: 200` は、その sandbox の通信経路で推論の認証が成功したことを示します。
`anthropic-organization-id` が返れば、利用予定の組織 ID と照合します。
未返却の場合や、複数アカウントが同じ組織の場合はこれだけで本人を区別できません。
メールアドレスや契約プランはこのコマンドから取得できません。
使用モデルにアクセスできない場合は `--refresh --model <利用可能なモデルID>` を付けてください。
この ID は初回の観測結果です。後から外部で sbx secret を変更した場合は追跡しないため、
認証設定はラッパー経由で更新してください。メールアドレスとの対応を手元で控えれば識別に使えますが、
同じ組織に所属するメールアドレス同士は区別できません。

個人の認証先を確実に合わせるには、`sbx-claude-setup <account>` のブラウザ認証で
目的のアカウントを選び、その token を保存して再起動します。併せてアカウント側の利用記録を照合します。
`sbx secret ls` は保存先の確認であって、token が属する個人の確認ではありません。

`setup-token` は通常の `/login` と同等の全機能ではなく、managed settings の 401 や
`/usage` などの制約が報告されています。認証失敗時に `/login` で直そうとせず、
kit・binding・token・sbx バージョンを確認してください。

## ccmanager での開発の段取り

### 最初の 1 回だけ（ホスト側のセットアップ）

```bash
mise install                     # sbx を導入
sbx login                        # Docker ID でサインイン
mise run sandbox:setup           # secret / network policy / skills / 通知用 SSH 鍵
ssh-add --apple-use-keychain ~/.ssh/id_ed25519  # コミット署名用の鍵を ssh-agent / Keychain へ
gh auth refresh -h github.com -s admin:ssh_signing_key  # signing key 登録用の scope を追加
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "sbx signing ($(hostname -s))"  # GitHub に Signing key として登録
mise run sandbox:build-template  # devcontainer と同じツールチェイン入りの template
mise run sandbox:mcp-add             # config/sbx/mcp*.yml の MCP をホストの sbx mcp へ登録
```

> [!NOTE]
> `sandbox:setup` の `sbx skills import` は **`--force`** を付けています。付けないと skill ごとに
> `Overwrite "<skill>"? [y/N]` を聞かれ、skill の数だけ y + Enter を打つことになります
> （プロンプトは sbx 自身の行入力なので、1 文字で受け付けるようにはできません）。
> ホストの `~/.claude/skills` 等が正で共有 store はその派生物、かつ sandbox は store を既定で
> read-only でマウントする（`sbx-agent` の `--skills` 既定が `readonly`）ため、上書きして
> 揃えるのが期待する動作になります。1 つずつ確認したいときは `--force` 無しで、
> 何が入れ替わるか見るだけなら `sbx skills import --dry-run` を手で流してください。

> [!IMPORTANT]
> sbx は共有 store（`--skills=off` 以外）を sandbox 内の `/home/agent/.claude/skills` にマウントしますが、
> `sbx-agent claude` は `CLAUDE_CONFIG_DIR` をホストの設定ディレクトリ（既定 `~/.claude`）に
> 向けるため、**Claude Code が実際に読むのは `$CLAUDE_CONFIG_DIR/skills`（ホストの実体）**です。
> `--config-dir ~/.claude-account2` のように skills 等を `../.claude/skills` への symlink で
> 共有しているディレクトリを使う場合、`sbx-agent` はリンク先（`~/.claude/skills` など）も
> 同じパスへマウントします（対象は `claude-share-config --list-entries` が返す共有 entry のみ）。基本は**書き込み可**ですが、
> リンクを辿った先が dotfiles リポジトリ内のものは read-only です。`settings.json` はファイルへの symlink で、
> sbx はこれを直接マウントできない（`workspace path exists but is not a directory` で作成に失敗する）ため、
> 代わりにリンク先のあるディレクトリ（`~/.claude`）を **read-only** で足して、symlink の連鎖ごと解決させます。
> そのため account2 / work3 の sandbox からはメインの `~/.claude`（会話履歴など）も読めます。
> statusline は `$CLAUDE_CONFIG_DIR/statusline.sh` が無ければ、隣の `.claude/statusline.sh` を使います。
> これが無いと sandbox 内でリンク切れになり、crit などの skill が見つかりません。マウントは作成時に決まるため、
> 既存の sandbox に反映するには `--new` で作り直してください。

> [!WARNING]
> `sbx-agent codex` では、`~/.codex/config.toml` の実体があるディレクトリ（dotfiles リポジトリの
> `codex/`）を**書き込み可で**重ねてマウントします。codex は「このディレクトリを信頼するか」の答えを
> `config.toml` に保存するため、read-only のままだと `failed to persist config.toml` で起動できません
> （一時ファイル + rename で書くのでファイル単体ではなくディレクトリが要ります）。
> ホストと同じく信頼設定は dotfiles 側に残りますが、sandbox 内の agent が `config.toml` /
> `hooks.json` を書き換えると、次にホストで codex を起動したときにその hooks や MCP の起動コマンドが
> 実行されます。sandbox の外に影響し得る経路なので、変更は `git diff codex/` で確認してください。

`sandbox:setup` の内容のうち secret 登録と `localhost:22` の network policy は **`sbx-agent` が sandbox を作るときに
自動でも実行**します。手で打たなくても普段の起動で揃うので、`sandbox:setup` は
「SSH 鍵・skills・ドキュメントサイトの許可・ホスト設定をまとめて用意したいとき」に使う入り口です。

ホストの sshd 側（`authorized_keys` 登録・リモートログイン・通知の表示許可）は
devcontainer と共通なので、[docs/devcontainer.md](./devcontainer.md) を一度だけ済ませてください。

sandbox で使う MCP は `config/sbx/mcp*.yml` から `mise run sandbox:mcp-add` で登録します。
`sbx-agent` は既定では読み込まないので、使うものだけ指定するか後から足します（[MCP の扱い](#mcp-の扱い)）。

### タスクごと

```bash
# 1. worktree を一括作成（全リポジトリに同じブランチの worktree ＋ task 設定を作る）
multi-worktree create feat/add-auth

# 2. task root へ移動
multi-worktree cd feat/add-auth

# 3. ccmanager を起動して preset を選ぶ
ccmc
```

ccmanager の preset 一覧で `Claude account1 (Docker Sandbox)` などの sandbox preset を選ぶと、
`sbx-agent` が次を自動でやってから agent にアタッチします。

1. sandbox 名を `<repo>-[<prefix>-]<branch>-<agent>` から決める（claude の preset は `a1` / `a2` / `w3` が prefix。既にあれば再利用）
2. ホスト側の前提条件（github secret / `localhost:22` の policy）を冪等に整える
3. ツールチェイン入り template があれば使って `sbx create`
   - ホストの git / aws / nvim 設定（read-only）・agent-lessons と agent 設定ディレクトリをマウント
     （gh のトークンファイルは渡さず `sbx secret` 経由にする）
   - 各 worktree の common git dir をマウント
   - git 設定・コミット署名・`AI_AGENT` などを `--env` で注入
   - crit / plannotator のポートを公開（host port は自動採番）
   - `--static-mcp` で登録済み MCP を読み込む（既定は読み込まない）
4. sandbox 内で初期化（nvim / agent-lessons の symlink と Basic Memory の登録 / `mac-host` SSH config / lefthook / crit）
5. `sbx run` でアタッチ

`multi-worktree dev` から直接起動することもできます。

```bash
multi-worktree dev feat/add-auth              # 既定 agent
multi-worktree dev feat/add-auth codex        # agent 指定
multi-worktree dev feat/add-auth --rm         # 終了時に sandbox を削除
multi-worktree dev feat/add-auth --devcontainer ccmanager  # devcontainer backend
```

### セッション中

| やりたいこと                      | コマンド（ホスト側の別端末から）                  |
| --------------------------------- | ------------------------------------------------- |
| sandbox 内でシェルを開く          | `sbx exec -it <sandbox> zsh`                      |
| lint を回す                       | `sbx exec <sandbox> bash -lc 'mise run lint:all'` |
| 公開ポートを確認（crit の UI 等） | `sbx ports <sandbox>`                             |
| 通信がブロックされた原因を見る    | `sbx policy log <sandbox>`                        |
| 一覧・リソースを見る              | `sbx` （TUI）/ `sbx ls` / `sbx inspect <sandbox>` |

### 片付け

```bash
multi-worktree remove feat/add-auth   # worktree を一括削除
sbx rm <sandbox-name>                 # sandbox（VM・インストール済みパッケージ・生成物）を削除
sbx prune                             # 使っていない sandbox をまとめて削除
```

`sbx stop` はインストール済みパッケージを保ったまま止めるだけなので、
翌日また同じタスクを続けるなら `stop` のままにしておくと起動が速くなります。

### ディスクを空ける（image layer の prune）

まずどこを食っているか見ます。ディスクは **ホストの Docker**（template をビルドする側）と
**sbx の image store / sandbox 本体** の 2 箇所に分かれて増えます。

```bash
mise run sandbox:disk
```

回収は `sandbox:prune` です。**既定は dry-run**（何が消えるか出すだけ）で、`--yes` を付けて
初めて実行します。

```bash
mise run sandbox:prune                          # 何が消えるか出すだけ
mise run sandbox:prune --yes                    # 停止済み sandbox + ホストの dangling image
mise run sandbox:prune --yes --template         # + ホストの template image
mise run sandbox:prune --yes --build-cache      # + build cache（cache mount は残す）
mise run sandbox:prune --yes --build-cache-all  # + build cache（cache mount も消す）
mise run sandbox:prune --yes --all              # --template + --build-cache
```

dry-run では消える候補を実際に列挙します（`sbx prune --dry-run`・`docker image ls`・
`docker buildx du`）。実行時にどれかの削除が失敗した場合は、残りを続けたうえで
**最後に非ゼロで終了**します。

素のコマンドは次の 6 つです。何がどこを空けるかが段ごとに違うので、効果とコストを
分けて把握しておくと選びやすくなります。

| コマンド                                                | 空く場所                                 | コスト                                                                                                    |
| ------------------------------------------------------- | ---------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `sbx prune`                                             | 停止済み sandbox（VM ごと）              | なし。**動いている sandbox は対象外**なので習慣的に打てる（`--dry-run` で事前確認、`--force` で確認省略） |
| `sbx template rm <tag>`                                 | sbx 側の template image                  | その template からの `sbx create` ができなくなる（`mise run sandbox:build-template` で作り直す）          |
| `docker image prune`                                    | ホストの dangling layer                  | なし（タグの付いていない層だけ）                                                                          |
| `docker image rm sbx-agent:<agent>`                     | ホストの template image（数 GB）         | 次回ビルドで layer cache が効かなくなる。**mise の再ダウンロードは起きない**（下記）                      |
| `docker builder prune --filter "type!=exec.cachemount"` | ホストの build cache（cache mount 以外） | なし。**mise の cache mount を残す**ので次回も再ダウンロードは起きない                                    |
| `docker builder prune`                                  | ホストの build cache（全部）             | **次回の `sandbox:build-template` が初回と同じフルインストールになる**（下記）                            |

> [!NOTE]
> `docker image rm sbx-agent:<agent>` と `docker builder prune` の違いが効きます。
> `Dockerfile.sandbox` は mise のインストール済みツールを
> `RUN --mount=type=cache,id=sandbox-mise-cache` で持っており、これは **image ではなく
> BuildKit の build cache 側**にあります。つまり image を消しても再ダウンロードは起きず、
> 素の `docker builder prune` を打つと全ツールを取り直すことになります。
>
> それを避けるのが `--filter "type!=exec.cachemount"` です。buildx の filter には `type` が
> あり、cache mount は `exec.cachemount` に当たります（buildx の docs がこの filter を
> そのまま例示しています）。`sandbox:prune --build-cache` はこの filter 付きで、
> `--build-cache-all` が filter 無しの全消しです。
> 容量だけ抑えたいなら `docker builder prune --max-used-space 10GB` のように上限を
> 決める手もあります（全消しではなくキャップ）。
>
> なお docker 29 系では `docker builder prune` は `docker buildx prune` そのもので、
> その `-a`/`--all` は「全未使用 cache」ではなく **internal/frontend image を含める**
> という意味なので、cache mount を残す目的には使えません。

> [!TIP]
> ホストの `sbx-agent:<agent>` は、`sbx template load` した時点で **sbx 側の image store に
> コピー済み**です。`sandbox:build-template` は load 後にホスト側を消しますが、手でビルドした
> ものや旧名の `sbx-agent:local` が残っていれば `--template` で落とせます（sandbox は動き続けます）。

sandbox の中で作った image を空けたいときは、sandbox 内で普通に `docker` を打ちます
（sandbox ごとに専用の docker daemon を持っているため、ホストには影響しません）。

```bash
sbx exec <sandbox-name> docker system prune -af
```

## ファイルシステムとパスの関係

### 編集は双方向・即時にホストへ反映される

既定の **direct mode** は container の bind mount と同じ理解で合っています。
filesystem passthrough でホストのディレクトリを直接見せているので、
sandbox 内の編集は**コピーや同期を介さず即座にホストへ反映**されます（逆方向も同じ）。
エージェントが編集している最中にホスト側のエディタで開けば、そのまま変更が見えます。

反映されないのは次の 3 つです。

| 場所                                | 実体                                                       |
| ----------------------------------- | ---------------------------------------------------------- |
| workspace として渡していないパス    | sandbox からそもそも見えない                               |
| sandbox 内の `$HOME` や `/` 配下    | VM 内だけに存在し、`sbx rm` で消える                       |
| clone mode（`--clone`）の作業ツリー | VM 内の別クローン。fetch / push するまでホストに出てこない |

### パスはホストと同じ絶対パスになる

ここが devcontainer との一番大きな違いです。

|            | devcontainer                                                           | Docker Sandboxes                               |
| ---------- | ---------------------------------------------------------------------- | ---------------------------------------------- |
| マウント先 | `devcontainer.json` の `target` で任意に指定（`/workspaces/...` など） | **ホストと同じ絶対パスに固定**（変更できない） |
| `$HOME`    | `/home/vscode`                                                         | `/home/agent`                                  |

devcontainer では `target` でパスが変わるため、linked worktree の `.git` file や common git dir 側の
`worktrees/<name>/gitdir` が**絶対パス**で相手を指していることが問題になり、
「workspace と common git dir をホストと同じ絶対パスに mount する」という工夫が必要でした
（[docs/devcontainer.md](./devcontainer.md) の「workspace と Git metadata の mount 範囲」）。

sandbox では**その工夫が標準動作**です。パスがずれないので、

- エラーメッセージやスタックトレースのパスがホストでそのまま開ける
- `.git` file の `gitdir:` も、common git dir 側の `gitdir` も、両方同じパスで解決する
- `direnv` / `mise` の信頼パスや設定ファイル内の絶対パスもそのまま通る

ただし **`$HOME` は別物**なので、`~/.config/...` や `~/.claude` を前提にしているものは
そのままでは解決しません。`sbx-agent` はここを 2 通りで埋めています。

| 対象                       | 方法                                                                                  |
| -------------------------- | ------------------------------------------------------------------------------------- |
| git 設定                   | `GIT_CONFIG_COUNT` / `KEY` / `VALUE` でホストのパスを直接指定                         |
| agent 設定（claude/codex） | `CLAUDE_CONFIG_DIR` / `CODEX_HOME` にホストのパスを設定                               |
| nvim                       | `~/.config/nvim` → ホストのパスへ symlink（nvim は XDG パスしか見ないため）           |
| agent-lessons              | `~/.local/share/agent-lessons` → ホストのパスへ symlink（skill が固定パスで読むため） |
| agent-lessons-context      | `~/.local/bin/agent-lessons-context` → dotfiles の実体へ symlink（hook が呼ぶため）   |

### git 操作で残る注意点は 1 つだけ

パスが一致するので devcontainer で必要だった考慮はほぼ消えますが、
**linked worktree の common git dir を追加 workspace として渡す**必要は残ります
（task root だけ渡すと `.git` pointer file の指す先が見えない）。
`sbx-agent` と `multi-worktree dev` が自動で渡します。詳細は
[worktree と Git metadata の mount](#worktree-と-git-metadata-の-mount) を参照してください。

### ホスト設定は symlink なので dotfiles リポジトリも渡す

mise の `[dotfiles]` は `~/.config` / `~/.claude` / `~/.codex` を **`symlink-each`** で配置します
（`mise.toml` の `[dotfiles."~/.config"]` を参照）。つまり `~/.config/nvim/init.lua` などは
実ファイルではなく **dotfiles リポジトリを指す symlink** です。

sbx はホストと同じ絶対パスにマウントするため、`~/.config/nvim` だけを渡すと
sandbox 内では symlink のリンク先（リポジトリのパス）が存在せず、**全部リンク切れ**になります。

そこで `sbx-agent` は **dotfiles リポジトリ自体も read-only で追加 workspace に渡します**。
パスがホストと同じなので、これだけで `~/.config` 配下の symlink がそのまま解決します。

リポジトリの場所は次の順で解決します。

1. 配置済み symlink のリンク先から逆算する。見るのは次の 3 つのパスだけで、
   この順に試して最初に見つかったものを使う
   （symlink でない・リンク先が有効なリポジトリでない場合は次へ進む）
   1. `~/.config/zsh/main.zsh`
   2. `~/.config/git/gitignore`
   3. `~/.claude/settings.json`
2. `DOTFILES_DIR`（既定以外の場所に clone している場合に export する運用）
3. `~/dotfiles`（既定の clone 先）

**1 を最優先にしている**のは、これが「実際にリンク先になっているツリー」を直接示すため
確実だからです。3 つとも有効なリポジトリを示さなかった場合に 2 → 3 の順で
フォールバックします（dotfiles 未適用で symlink が 1 つも無い場合など）。`mise.toml` と `.git` があるだけでは同じ構成の別プロジェクトを
誤認するため、`mise.toml` に `[dotfiles]` の宣言があることも確認します。

どれも外れた場合は warning を出して続行します（ホスト設定が読めない状態になるため、
`DOTFILES_DIR` を export してください）。

追加マウントを省略するのは **workspace がリポジトリ root そのものだったときだけ**です。
サブディレクトリ（`~/dotfiles/config/devcontainer` など）を workspace にした場合は
root が sandbox から見えないため、`~/.config` 配下の symlink を解決するには
リポジトリの追加マウントが必要になります。

> [!NOTE]
> 同じ理由で、Docker の build context も「配置先」ではなく**リポジトリ側**を使います。
> BuildKit はコンテキストの外を指す symlink を辿らないため、`~/.config/devcontainer` を
> context にすると `COPY mise.toml` が `"/mise.toml": not found` で失敗します。
> `mise run sandbox:build-template` はリポジトリの `config/devcontainer` を context にし、
> devcontainer 側は `initialize.sh` が symlink を解決したコピーを作ってそれを context にします
> （[docs/devcontainer.md](./devcontainer.md#symlink-で配置されたホスト設定の扱い) 参照）。

## clone mode（`--clone`）とは

`--clone` を付けると、**sandbox が VM 内に自分用の git clone を作ってそこで作業する**モードになります。

|                             | direct mode（既定）            | clone mode（`--clone`）                       |
| --------------------------- | ------------------------------ | --------------------------------------------- |
| エージェントが編集するもの  | ホストの working tree そのもの | VM 内の別クローン                             |
| ホストへの反映              | 即時                           | fetch / push するまで出てこない               |
| ホスト側リポジトリ          | 読み書き                       | `/run/sandbox/source` に read-only でマウント |
| 生成物（`node_modules` 等） | **ホストに書かれる**           | VM 内だけ                                     |
| 切り替え                    | —                              | 作成時に固定（後から変更するには作り直し）    |

レビュー前に何も手元へ入れたくないときや、同じリポジトリで複数エージェントを並列に走らせたいときに
向いています。ブランチは作成時にホストが checkout している ref に追従するだけで、自動では作られません。

### multi-worktree では使えない

`sbx` は **main worktree 以外から `--clone` を拒否します**。
clone mode はホストのリポジトリを read-only で bind mount してそこから clone しますが、
linked worktree の `.git` は「ファイル」で、中身は common git dir を指す `gitdir:` という
ポインタです。read-only マウントされた worktree ディレクトリだけでは
このポインタの先（実体リポジトリの `.git`）に到達できず、clone 元として使えません。

公式ドキュメントも「clone mode is rejected from inside a Git worktree other than the main one」
と明記しており、`multi-worktree` の task root は linked worktree の集まりなので対象外です。

そのため生成物の置き場所を分ける目的には clone mode を使えず、
次の運用にしています。

## 生成物（`node_modules` 等）の扱い

sandbox では `node_modules` / `.venv` / `target` などの生成物を**分離しません**。
sandbox 内で `npm install` 等をすると、ホストの workspace（worktree）にそのまま Linux 版が書かれます。

devcontainer では `mount-container-only-dirs.sh` でコンテナローカル領域へ bind mount して隠していますが、
sbx の agent は microVM の中でさらにコンテナとして動いており、`sudo` しても root は
`CAP_SYS_ADMIN` を持ちません（`/proc/self/status` の `CapBnd` が Docker 既定の `a80425fb`）。
共有フォルダ上に限らず `/tmp` 同士の `mount --bind` も `permission denied` になるため、
mount による分離は使えません。

代わりにディレクトリ単位で持ち主を分けます。生成物は `.gitignore` 済みなので、
checkout 間で混ざることはありません。

| ディレクトリ                              | 生成物の持ち主 | 用途                                                     |
| ----------------------------------------- | -------------- | -------------------------------------------------------- |
| worktree（`multi-worktree` / ccmanager）  | sandbox        | エージェントの実装・テスト（Linux 版の `node_modules`）  |
| main のチェックアウト（例: `~/dotfiles`） | ホスト         | 動作確認。ブランチを checkout してホストで install・実行 |

- worktree でホストから install やテストをしない（ネイティブモジュールが Linux 版 / macOS 版で
  入れ替わって片方で壊れる）。
- ホストで動作確認したいときは、main のチェックアウトで対象ブランチを checkout してから行う。

## worktree と Git metadata の mount

`multi-worktree` の task root には各リポジトリの **linked worktree** が並びます。linked worktree の
`.git` は file であり、実体リポジトリの common git dir（`<repo>/.git`）を**絶対パス**で参照します。
task root だけを workspace として渡すと、sandbox 内から common git dir が見えず git が壊れます
（公式ドキュメントも
[Host worktree](https://docs.docker.com/ai/sandboxes/workflows/git/) の制限として
「`.git` pointer file を解決できず git が使えない」と明記しています）。

sbx はホストと同じ絶対パスに workspace をマウントするため、common git dir を追加 workspace として
渡せばホスト・sandbox のどちらでも同じパスで git が解決できます。`multi-worktree dev` と `sbx-agent` は
`git rev-parse --path-format=absolute --git-common-dir` でこれを解決して自動で渡します。
devcontainer 側の mount 範囲と同じ考え方で、詳細は
[docs/devcontainer.md](./devcontainer.md) の「workspace と Git metadata の mount 範囲」を参照してください。

- 実体リポジトリの working tree や兄弟ディレクトリは渡さないので、sandbox からは見えません
- relative-paths 形式の worktree（`git worktree add --relative-paths` /
  `worktree.useRelativePaths`）は絶対パス mount では解決できないため、warn を出してスキップします
- `--clone`（clone mode）は **main 以外の worktree からは使えません**。sbx 側が
  「read-only bind mount が worktree の `.git` pointer file を解決できない」として拒否するため、
  multi-worktree の task root では利用できません

## ホストの git 設定とコミット署名

sandbox 内の `$HOME` はホストとは別物なので、`~/.config/git/config` を mount しただけでは
git に読まれません。`sbx-agent` は `GIT_CONFIG_COUNT` / `GIT_CONFIG_KEY_n` / `GIT_CONFIG_VALUE_n`
で以下を注入します（`pushInsteadOf` 以外は devcontainer の `post-create.sh` と同じ内容。
devcontainer は SSH で GitHub に出られるため `pushInsteadOf` の打ち消しは不要）。

| 設定                                    | 目的                                                         |
| --------------------------------------- | ------------------------------------------------------------ |
| `include.path`                          | ホストの `~/.config/git/config`（`user.name` 等）を取り込む  |
| `core.excludesfile`                     | ホストのグローバル gitignore を使う                          |
| `credential.https://github.com.helper`  | `!gh auth git-credential` で gh の認証を使う                 |
| `url.https://github.com/.insteadOf`     | SSH 形式の remote を HTTPS に書き換える                      |
| `url.https://github.com/.pushInsteadOf` | ホスト設定の push を SSH に寄せる `pushInsteadOf` を打ち消す |
| `gc.worktreePruneExpire`                | 見えていない worktree を git gc が消さないようにする         |

コミット署名は **SSH agent forwarding**（sbx の既定で有効）を使います。
ホストのパスは sandbox 内に存在しないため、鍵ファイルではなく forwarded agent の公開鍵を
`key::<pubkey>` 形式で `user.signingkey` に設定します。

```
gpg.format      = ssh
user.signingkey = key::<~/.ssh/id_ed25519.pub の鍵>
commit.gpgsign  = true
```

署名に使う鍵は `~/.ssh/id_ed25519`（`SBX_AGENT_SIGNING_KEY` で変更可）に固定しています。
`ssh-add -L` の先頭の鍵を使うと、再起動後に agent へ鍵が入る順番が変わったとき（他の SSH 接続で
別の鍵が先に登録された等）に GitHub 未登録の鍵で署名して Unverified になるためです。

署名用の鍵を ssh-agent に登録できない場合は `commit.gpgsign = false` にして警告します。
ホストの gitconfig が GPG 署名を有効にしていても GPG 秘密鍵は sandbox に渡らないため、
無効化しないと commit が毎回失敗するからです。

macOS の ssh-agent は再起動のたびに空になり、`~/.ssh/config` の `AddKeysToAgent yes` も
「SSH で鍵を使った時点」でしか登録しません。ホストの git が GPG 署名・HTTPS push だと
SSH 鍵を使う機会が無いため、空のままになりがちです。そこで `sbx-agent` は署名用の鍵が agent に
無いとき、自分で `ssh-add` して読み込みます。パスフレーズ無しの鍵はそのまま読み込めます
（Keychain には何も保存されないので、`--apple-load-keychain` だけでは再起動のたびに空のままでした）。
パスフレーズ付きの鍵は、Keychain に保存済みなら非対話で、未保存なら一度だけ端末でパスフレーズを
聞いて Keychain に保存します。先に手で済ませておく場合は次を実行してください。

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
ssh-add -L   # 公開鍵が表示されれば OK
```

署名を GitHub で Verified にするには、同じ公開鍵を GitHub に **Signing key** として登録しておく
必要があります（Authentication key とは別枠）。

`ssh-add -L` が `Could not open a connection to your authentication agent` になる場合は
`SSH_AUTH_SOCK` が古い（tmux の古いセッションなど）ので、新しいシェルから実行してください。

### 署名の検証（`allowed_signers`）

SSH 署名を `git log --show-signature` などで検証するには `gpg.ssh.allowedSignersFile` が必要です
（無いと `gpg.ssh.allowedSignersFile needs to be configured` になります）。sandbox で作った commit は
SSH 署名なので、ホストで検証するときも同じです。

`sbx-agent` は署名を有効にするとき、次をまとめて行います。

1. ホストの `~/.config/git/allowed_signers` に `<user.email> namespaces="git" <署名用の公開鍵>` を
   冪等に追記する（email は workspace で有効な `user.email`。work 用の `includeIf` も反映される）
2. そのファイルを同じ絶対パスで read-only マウントし、sandbox の `gpg.ssh.allowedSignersFile` に指定する

ホストの `~/.config/git/config`（`templates/git/config.tera`）も同じファイルを
`gpg.ssh.allowedSignersFile` に指定しているので、sandbox の commit をホストでも検証できます。
マウントは作成時に固定されるため、既存の sandbox には `sbx-agent --new` で反映してください。

## ツールチェイン（カスタム template）

### なぜホストのツールが使えないのか

sandbox は **Linux の microVM** です。devcontainer が Linux コンテナだったのと同じで、
**中のツールは Linux バイナリでないと動きません**。ホスト（macOS）に mise で入れたツールは
Darwin/arm64 バイナリなので、仮に `~/.local/share/mise` をマウントしても実行できません。
つまり **devcontainer と同じく、sandbox 用に Linux 版を別途インストールする必要があります**。

workspace としてマウントしたディレクトリは「ファイルが見える」だけで、ホストの PATH や
インストール済みツールは一切引き継がれません。sandbox 内から見えるツールは

1. base image（`docker/sandbox-templates:<variant>`）が持っているもの
2. kit / カスタム template で足したもの
3. エージェントがセッション中に `apt`/`npm` 等で入れたもの（`sbx rm` で消える）

のいずれかです。

### このリポジトリの template

`config/devcontainer/Dockerfile.sandbox` が、**devcontainer と同じ `mise.toml`** を使って
sandbox 用の image をビルドします。**agent ごとに、中身は同じで base image だけが違う template**
（既定では `sbx-agent:claude` / `sbx-agent:codex`。`sbx-agent:copilot` は指定時のみ。下記）を作り、`sbx-agent` が
agent に合ったものを自動で選びます。ccmanager などから agent を切り替える側は何も意識しません。

| agent   | template            | base image（FLAVOR）                          |
| ------- | ------------------- | --------------------------------------------- |
| claude  | `sbx-agent:claude`  | `docker/sandbox-templates:claude-code-docker` |
| codex   | `sbx-agent:codex`   | `docker/sandbox-templates:codex-docker`       |
| copilot | `sbx-agent:copilot` | `docker/sandbox-templates:copilot-docker`     |

1 つの template を全 agent で使い回せないのは、sbx が template の base（FLAVOR）を記録し、
`sbx create <agent>` がその agent 用の kit（認証の注入・network policy など）を当てるためです。
FLAVOR と agent が合わないと `failed to apply kit to sandbox` で作成に失敗するか、kit が当たらず
agent がログインを求めます（agent を含まない `shell-docker` でも同じ。実機で確認）。
使わない agent はディスクを食うだけなので、作る agent は実行時に fzf で選びます（claude を選択済み。
Tab で切り替え、Enter で確定）。引数か `SBX_TEMPLATE_AGENTS` で指定すると fzf は出ません。
fzf が無い・端末でないときは claude だけを作ります。

```bash
mise run sandbox:build-template                # fzf で選ぶ
mise run sandbox:build-template codex copilot  # 指定した agent だけ
SBX_TEMPLATE_AGENTS="claude codex" mise run sandbox:build-template
```

ビルドしていない agent の preset（ccmanager の codex など）を選んだ場合、その場でビルドはされず
`sbx create` が失敗します。`sbx-agent` が `mise run sandbox:build-template <agent>` の手順を表示するので、
ビルドしてから選び直してください（`--no-template` を付ければツールチェイン無しで起動はできます）。

やっていること:

0. build context は **dotfiles リポジトリの `config/devcontainer/`**（配置先の
   `~/.config/devcontainer` ではない）。配置先が実体ファイルでない場合、BuildKit は
   コンテキスト外を指す symlink を辿らず `COPY` が "not found" で失敗するため
1. `FROM docker/sandbox-templates:<agent>-docker`（上の表。Ubuntu + 非 root の `agent` ユーザー + sudo）。
   **`-docker` 版でないと sandbox 内に dockerd がありません**（通常版は docker CLI だけ）。
   `-docker` 版から作った sandbox はエージェントのコンテナが microVM 内で特権モードになり、
   `/var/lib/docker` に専用ボリュームが付いて dockerd が自動起動します
2. mise を `/usr/local/bin` に入れ、`config/devcontainer/mise.toml` を `/mise/config.toml` へ COPY
3. `mise install` で devcontainer と同じツール群を入れる（BuildKit の cache mount で差分ビルド、
   `GH_TOKEN` は build secret で渡してレート制限を避ける）
4. `tasks/` / `lint/` / `scripts/` / `lefthook.local.yml` を **devcontainer と同じ
   `~/.config/devcontainer` 配下**（sandbox 内では `/home/agent/.config/devcontainer`）へ COPY。
   こうすると tasks が参照する `${XDG_CONFIG_HOME:-$HOME/.config}/devcontainer/lint/...` が
   パスの書き換え無しでそのまま解決します
5. `scripts/` を PATH の先頭に置き、`crit` ラッパーが mise shim より先に来るようにする
6. ビルドした image を `docker image save` → `sbx template load` で sbx の image store へ入れる
   （sbx の Docker daemon はホストの image store を共有しないため、tar 経由で渡す必要があります）。
   load 後はホスト側の image を消します（agent の数だけ数 GB ずつ増えるため。mise の
   インストール済みツールは cache mount に残るので、次回のビルドも差分だけで済みます）

**agent CLI（claude / codex / copilot）も mise で入れます**（バージョンは
`config/devcontainer/mise.toml`）。base image には対応する agent しか入っていないため、
どの template からでも claude / codex / copilot を同じバージョンで使えるようにしています。PATH は
mise の shim が base image の `~/.local/bin` より前にあるので、シェルから呼ぶ agent は mise 側になります。
特定のツールを外したいときは `--build-arg DISABLE_TOOLS=<tool>,...` で除外できます。

`sbx-agent` は **agent に合わせて `sbx-agent:<agent>` を template として渡します**。別名を使う場合は
`--template` か `SBX_AGENT_TEMPLATE`（全 agent に同じ template が効くので FLAVOR に注意）、
`--no-template` で sbx の既定 template に戻せます
（優先順位は `--no-template` > `--template` > `SBX_AGENT_TEMPLATE` > 既定）。

template を渡すときは **`--pull missing` を付けます**。`sbx create` の `--pull` は
**既定が `always`** なので（`sbx create --help`。sbx 0.47.0 で確認）、付けないと
`sbx-agent:claude` のようなローカルにしか無い template をレジストリから引こうとします。
`never` ではなく `missing` なのは、`SBX_AGENT_TEMPLATE` にレジストリ上の参照を指定した場合に
取得できなくなるのを避けるためです（ローカルに有れば引きません）。

`mise.toml` や `tasks/` / `lint/` / `scripts/` を変えたら **template を再ビルド**してください。

## ホスト連携（mac-host への SSH 経路）

devcontainer と同じ `mac-host` という SSH host 名でホストの sshd へ接続します。
通知・`host-tmux`・plannotator の reverse tunnel・crit の再レビュー通知はすべてこの経路を使います。

devcontainer との違いは 2 点です。

1. **ホストは `localhost` ではなく `host.docker.internal`。** sandbox の `localhost` は VM 自身を指します。
2. **network policy で明示的に許可が必要。** sandbox プロキシは `host.docker.internal` を
   `localhost` に書き換えて転送するため、許可ルールは `localhost:<port>` の形で書きます。

```bash
sbx policy allow network localhost:22   # mise run sandbox:setup が実行する
```

鍵は devcontainer と同じ専用鍵（`~/.ssh/id_docker_devcontainer`）を read-only でマウントします。
個人鍵は渡しません（コミット署名は別途 ssh-agent forwarding を使います）。
鍵の生成とホストの `authorized_keys` への登録、リモートログインの有効化は devcontainer と
共通の手順です（[docs/devcontainer.md](./devcontainer.md) 参照）。`mise run sandbox:setup` が
`initialize.sh` を流用して鍵を用意します。

### 初期化の流れ

sbx には `postCreateCommand` に相当する仕組みが無いため、`sbx-agent` が sandbox 作成直後に
`sbx exec` で `scripts/sandbox-post-create.sh` を 1 度だけ実行します
（`sbx exec -d` は 0.45.0 で非対応になったので前景で実行します）。

| 処理                          | 内容                                                                                                                 |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `~/.config/ssh/config` の生成 | `mac-host` → `host.docker.internal`。鍵は 600 でコピーしてから使う                                                   |
| `~/.crit.config.json` の生成  | `no_open` / `agent_cmd`（devcontainer と同じ内容）                                                                   |
| `~/.crit-host-port` の記録    | ホスト側で `sbx ports` が調べた host port を `SBX_CRIT_HOST_PORT` で受け取って書き出す                               |
| NO_PROXY にローカル宛てを追加 | `/etc/sandbox-persistent.sh` に `0.0.0.0` / `localhost` / `127.0.0.1` / `::1` を足す（下記）                         |
| `~/.claude.json` のコピー     | ホストの `~/.claude.json` をマウント元からコピー                                                                     |
| lefthook のインストール       | `INSTALL_LOCAL_LEFTHOOK=1` のときのみ。task root が multi-worktree なら直下の各リポジトリへ、通常は workspace 自体へ |

> [!NOTE]
> sbx は `HTTP(S)_PROXY` を sandbox のプロキシに向けますが、既定の `NO_PROXY` には `0.0.0.0` が
> 入っていません。crit は `CRIT_HOST=0.0.0.0` で待ち受け、client も `0.0.0.0:7842` へ接続するため、
> そのままだと接続がプロキシ経由になって `Approval required…` が返り、crit が起動に失敗します。
> plannotator など sandbox 内のローカルサーバーへの接続も同じ問題を踏みうるので、初期化スクリプトが
> `/etc/sandbox-persistent.sh` にループバック系をまとめて足します（bash / zsh の両方が読む）。
> `crit` ラッパーと `plannotator-browser` も実行時に同じ値を足すので、二重に効きます。
> いずれも template に入っているため、既存の sandbox へは `mise run sandbox:build-template` →
> `sbx-agent --new` で反映してください。

> [!NOTE]
> `gh stack`（[github/gh-stack](https://github.com/github/gh-stack)）は、devcontainer と sandbox では
> **gh の公式 extension として template（image）のビルド時に入れています**
> （`Dockerfile` / `Dockerfile.sandbox` の `gh extension install github/gh-stack --pin ...`）。
> gh 2.102 以降、`stack` は「公式 extension を入れてください」と表示して exit 1 するだけの
> 組み込みコマンドで、extension が入っていればそちらが優先されます（同名の alias は
> `already a gh command or extension` で作れません）。
>
> - mise には gh extension を入れる backend が無いため、mise ではなく Dockerfile で入れています。
>   バージョンは `ARG GH_STACK_VERSION` で固定し、renovate が追従します。
> - 入り先は `~/.local/share/gh/extensions` で `~/.config/gh` とは別です。devcontainer で
>   `~/.config/gh` を read-only mount していても、sandbox で mount していなくても image のものが見えます。
> - 更新は他のツールと同じく template の再ビルド（`mise run sandbox:build-template` → `sbx-agent --new`、
>   devcontainer は rebuild）です。

crit（7842）と plannotator（19433）の **host port は固定せず sbx に採番させます**。
devcontainer が `appPort: 127.0.0.1::7842` で自動採番していたのと同じ理由で、
sandbox を複数同時に起動してもポートが衝突しません。割り当てられた port は
`sbx ports <sandbox>` で確認できます。

ホスト連携が不要な場合は `sbx-agent claude --no-host-bridge` のように agent 名を指定して無効化できます。

## devcontainer との機能対応表

凡例: ✅ 再現済み / ⚠️ 部分的・要設定 / ❌ 未実現

### initializeCommand（`initialize.sh`）

| devcontainer でやっていたこと    | sandbox                                                                                                                                                                       |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| mount source の事前作成          | ✅ `mise run sandbox:setup` が同じ `initialize.sh` を流用する                                                                                                                 |
| 通知用 SSH 鍵の生成              | ✅ 同上（`~/.ssh/id_docker_devcontainer` を read-only でマウントして使う）                                                                                                    |
| 署名用 SSH 鍵の生成・`.pub` 同期 | ⚠️ sandbox の署名には不要（ssh-agent forwarding を使う）。ただし `sandbox:setup` が流用する `initialize.sh` は devcontainer 用の署名鍵も生成し、GitHub への登録手順を表示する |

### Dockerfile / features

| devcontainer でやっていたこと                                    | sandbox                                                                                                                                               |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| docker-in-docker feature                                         | ✅ 標準で sandbox 専用 docker daemon を持つ                                                                                                           |
| DinD データを `${devcontainerId}` スコープの named volume に分離 | ✅ 不要。sandbox ごとに独立（`sbx rm` で消える）                                                                                                      |
| mise + 各種ツール（lint 群 / 言語処理系 / crit / plannotator）   | ✅ `Dockerfile.sandbox` が同じ `mise.toml` で入れる                                                                                                   |
| mise cache mount によるリビルド高速化                            | ✅ 同じ BuildKit cache mount 方式                                                                                                                     |
| `crit` ラッパーを mise shim より前の PATH に置く                 | ✅ `ENV PATH=~/.config/devcontainer/scripts:/mise/data/shims:$PATH`                                                                                   |
| `tasks/` / `lint/` を `~/.config/devcontainer` 配下に置く        | ✅ 同じパスへ COPY（tasks の config 参照がそのまま解決する）                                                                                          |
| claude / codex / copilot の CLI                                  | ✅ mise で入れる（base image には claude しか無いため。バージョンは `config/devcontainer/mise.toml`）                                                 |
| nvim（設定をホストと共有）                                       | ✅ `aqua:neovim/neovim` を同じ `mise.toml` に追加し、`~/.config/nvim` を `:ro` で渡して symlink（lockfile は `AI_AGENT=1` のとき state dir へ逃がす） |
| Ubuntu 24.04 + zsh を既定シェルに                                | ✅ `chsh -s /usr/bin/zsh agent`。`/etc/zsh/zshenv` から `/etc/sandbox-persistent.sh` も読む                                                           |

### mounts

| devcontainer の mount                     | sandbox                                                                                                           |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `~/.config/git/config`                    | ✅ `:ro` で渡し、`include.path` で取り込む                                                                        |
| `~/.config/git/gitignore`                 | ✅ `:ro` で渡し、`core.excludesfile` に設定                                                                       |
| `~/.config/gh`                            | ⚠️ **マウントしない**（`hosts.yml` にトークンが平文で入りうるため）。`sbx secret set github` でプロキシが注入する |
| `~/.aws/config`                           | ✅ `:ro`                                                                                                          |
| `~/.agents`                               | ✅ `:ro`                                                                                                          |
| `~/.ssh/known_hosts`                      | ✅ `:ro`                                                                                                          |
| 通知用 SSH 鍵                             | ✅ `:ro`（sandbox 内で 600 にコピーして使う）                                                                     |
| `~/.claude.json`                          | ✅ `:ro` で渡し、post-create でコピー                                                                             |
| `~/.claude` / `~/.codex` / `~/.copilot`   | ✅ agent ごとに rw で渡す                                                                                         |
| `~/.claude-account2` / `~/.claude-work3`  | ✅ `--config-dir` で切り替え（preset ごとに別 sandbox）                                                           |
| workspace をホストと同じ絶対パスに mount  | ✅ sbx の標準動作                                                                                                 |
| common git dir（実体リポジトリの `.git`） | ✅ 追加 workspace として自動で渡す                                                                                |
| `~/.config/devcontainer`（設定ツリー）    | ✅ マウントではなく template に COPY（再ビルドで更新）                                                            |
| `~/.config/mise`                          | ⚠️ 既定では渡していない（`extra_workspaces` で追加可）                                                            |
| `~/.coderabbit`                           | ⚠️ `extra_workspaces` で追加する                                                                                  |
| `~/.claude/settings.json` だけ read-only  | ❌ ディレクトリ全体を rw で渡している                                                                             |

### remoteEnv / ポート

| devcontainer                                                                              | sandbox                                                     |
| ----------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| `AI_AGENT` / `TERM` / `HOST_USER` / `LEFTHOOK_CONFIG` / `MISE_TRUSTED_CONFIG_PATHS`       | ✅ `--env` で渡す                                           |
| `CRIT_HOST` / `CRIT_PORT` / `CRIT_ALLOW_UNAUTHENTICATED_NETWORK` / `CRIT_NO_UPDATE_CHECK` | ✅ `--env` で渡す                                           |
| `PLANNOTATOR_REMOTE` / `PLANNOTATOR_PORT` / `PLANNOTATOR_BROWSER`                         | ✅ `--env` で渡す                                           |
| `GH_TOKEN`（build secret + remoteEnv）                                                    | ✅ `sbx secret set github --command 'gh auth token'` で代替 |
| `appPort: 127.0.0.1::7842`（host port 自動採番 + `~/.crit-host-port` 記録）               | ✅ `--publish 7842` で採番させ、`sbx ports` で調べて渡す    |

### postCreateCommand（`post-create.sh`）

| devcontainer でやっていたこと                                                                     | sandbox                                                                                 |
| ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `include.path` / `core.excludesfile` / credential helper / `insteadOf` / `gc.worktreePruneExpire` | ✅ `GIT_CONFIG_*` で注入                                                                |
| 各リポジトリへの `lefthook.local.yml` 配置と `lefthook install`                                   | ✅ `sandbox-post-create.sh` で実行（`INSTALL_LOCAL_LEFTHOOK=1` のときのみ。既定は無効） |
| `~/.claude.json` のコピー                                                                         | ✅ 同上                                                                                 |
| `~/.crit.config.json` の生成                                                                      | ✅ 同上                                                                                 |
| コミット署名（専用鍵 + `allowed_signers`）                                                        | ✅ ssh-agent forwarding で署名し、ホストの `allowed_signers` をマウントして検証もできる |
| `~/.claude-account2` / `-work3` への symlink 共有                                                 | ⚠️ 不要。`CLAUDE_CONFIG_DIR` がホストのディレクトリを直接指すため共有される             |
| `mount-container-only-dirs.sh`（`node_modules` / `.venv` / `target` の分離）                      | ❌ 使わない（mount できないため。worktree は sandbox 用と割り切る）                     |

### postStartCommand（`post-start.sh`）

| devcontainer でやっていたこと    | sandbox                                                                 |
| -------------------------------- | ----------------------------------------------------------------------- |
| `mise trust`                     | ✅ 不要。`MISE_TRUSTED_CONFIG_PATHS=/mise:<workspace>` で代替           |
| `mac-host` への SSH config 生成  | ✅ `sandbox-post-create.sh` で生成                                      |
| crit の host port 取得・記録     | ✅ ホスト側で `sbx ports` → `SBX_CRIT_HOST_PORT`                        |
| crit の host port をホストへ通知 | ⚠️ 記録はするが mac-host への通知は省略（`sbx ports` で確認できるため） |

### コンテナ内でできていたこと

| できていたこと                                       | sandbox                                                                                                          |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `docker compose` で DB 等を建てる                    | ✅ sandbox 専用 docker daemon で可能                                                                             |
| `mise run lint:*` / `fix:*`                          | ✅ template に mise + tasks + lint 設定が入っている                                                              |
| lefthook の pre-commit lint 一式                     | ✅ `AI_AGENT=1` / `LEFTHOOK_CONFIG` + post-create の `lefthook install`（`INSTALL_LOCAL_LEFTHOOK=1` のときのみ） |
| 共有 skills（`~/.claude/skills`）                    | ✅ `sbx skills import` + `--skills=readonly`                                                                     |
| ホスト macOS への通知（SSH → `macos-notify-cli`）    | ✅ `mac-host` 経由（`sbx policy allow network localhost:22` が必要）                                             |
| `host-tmux`（ホスト tmux pane の参照）               | ✅ 同じスクリプトが PATH にあり、`mac-host` 経由で動く                                                           |
| crit のレビュー UI                                   | ✅ crit 本体 + ラッパー + ポート公開 + host port 記録が揃っている                                                |
| plannotator の SSH reverse tunnel                    | ✅ `PLANNOTATOR_*` と `ensure-plannotator-tunnel` が揃っている                                                   |
| `ai-rule-hook`（セッション終了時のルール提案）       | ✅ スクリプトが image に入り、`~/.claude` もマウントされている                                                   |
| MCP（ホストで認証済みのものを使う）                  | ✅ `sbx mcp` + `--static-mcp`（[詳細](#mcp-の扱い)）                                                             |
| 生成物（`node_modules` / `.venv`）をホストに書かない | ❌ worktree に書かれる（[運用で分ける](#生成物node_modules-等の扱い)）                                           |

### 残っている差分

| 項目                                   | 状況                                                                             |
| -------------------------------------- | -------------------------------------------------------------------------------- |
| `~/.claude/settings.json` の read-only | devcontainer は settings.json だけ ro で重ね mount していたが、sandbox は全体 rw |
| `~/.config/mise`                       | 既定では渡していない（必要なら `extra_workspaces`）                              |

### まとめ

ツールチェイン・ホスト連携・MCP はすべて移植済みで、
**残る差分は生成物の分離（mount できないため運用で分ける）と
`~/.claude/settings.json` の read-only 化**です。
隔離・認証情報・コミット署名については devcontainer より安全な作りになっています。

## MCP の扱い

sandbox では **MCP サーバへの接続をホスト側（`sbx mcp` の gateway）に寄せます**。
sandbox 内の Claude Code は自身の MCP 設定にある stdio サーバを読まず、ホストに登録したサーバを
gateway 経由で使います（Codex には同じ制限を入れていません。下記）。

| 経路                                                  | MCP サーバが動く場所 | sandbox での扱い                                                  |
| ----------------------------------------------------- | -------------------- | ----------------------------------------------------------------- |
| `sbx mcp add --url`（リモート）                       | リモート             | ✅ 使う。gateway がホストから接続する（認証情報はホストに留まる） |
| `sbx mcp add --command`（stdio）                      | **ホスト**           | ✅ 使う。agent は gateway 経由でのみ接続する                      |
| エージェント自身の MCP 設定（`~/.claude.json` / APM） | sandbox 内の VM      | ❌ 読み込ませない（下記）                                         |

### エージェント自身の MCP 設定を止める

sandbox は `~/.claude` や `~/.claude.json` をホストと共有するため、そのままだとホスト向けに
`claude mcp add` したサーバ（`npx mcp-remote https://mcp.notion.com/mcp` など）が sandbox 内でも
起動し、network policy でブロックされたり、OAuth の認可が VM 内で完結せずに失敗したりします。

そこで template（`Dockerfile.sandbox`）に Claude Code の managed settings の drop-in
（`/etc/claude-code/managed-settings.d/50-mcp.json`、中身は `config/devcontainer/claude/mcp-policy.sandbox.json`）
を置いています。

```json
{
  "allowManagedMcpServersOnly": true,
  "allowedMcpServers": [{ "serverUrl": "*://*/*" }]
}
```

- 許可リストに `serverUrl` しか無いため、**stdio サーバ（`npx` / `uvx` で起動するもの）はすべて読み込まれません**。
  gateway は URL で登録されるので影響を受けません。
- remote（HTTP / SSE）サーバは許可リストを通りますが、宛先は network policy で別途止まります。
- managed settings なので `~/.claude/settings.json` などの共有設定では上書きできず、ホスト側の
  `~/.claude.json` も書き換えません（ホストでは今まで通り全サーバが使えます）。
- この制限は Claude Code だけです。Codex などは自身の設定（`~/.codex/config.toml` など）に MCP サーバが
  あれば sandbox 内でも起動します（このリポジトリでは APM から MCP を登録しないので、手で追加しない限り空です）。
- 反映には template の再ビルド（`mise run sandbox:build-template`）と sandbox の作り直しが必要です。
  sandbox 内で `claude mcp list` を実行し、gateway 以外が出ないことを確認してください。

### 登録するサーバの管理

MCP サーバの定義とバージョンは `config/sbx/mcp.yml` で管理します。書式は APM の
`apm.yml` の `dependencies.mcp` と同じで、すべて self-defined（`registry: false`、起動方法を自分で書く形式）で書きます。
ホストの agent には登録しません（`apm install` は `--only apm`。[docs/apm.md](./apm.md#mcp-サーバ)）。

```yaml
dependencies:
  mcp:
    - name: notion
      registry: false
      transport: http
      url: https://mcp.notion.com/mcp
    - name: chrome-devtools
      registry: false
      transport: stdio
      command: npx
      args: ["-y", "chrome-devtools-mcp@1.10.1", "--browser-url=http://localhost:9222"]
```

- stdio サーバはパッケージを `args` の `<package>@<version>` で固定します。Renovate が `npx` は npm、
  `uvx` は PyPI の新しいバージョンで更新します（`command` の直後に `args` を書いたものが対象）。
- work3 / private など特定の環境だけで使うサーバは `config/sbx/mcp.<name>.yml` に書きます。
  gitignore 済みなのでコミットされず、Renovate の更新対象にもなりません。雛形は `mcp.work2.yml.example` / `mcp.work3.yml.example` です。
  同じ name を複数のファイルに書いた場合は、先に読んだ方（`mcp.yml`）を使います。

```bash
mise run sandbox:mcp-add     # mcp*.yml を sbx mcp に反映する（OAuth は初回だけブラウザで認可）
```

`sandbox:mcp-add` は `registry: false` のエントリを次のように `sbx mcp add` の引数へ変換します。

| mcp.yml                         | sbx mcp add                                            |
| ------------------------------- | ------------------------------------------------------ |
| `transport: http` / `sse` + url | `--url <url>`（`headers` は `--header 'Name: value'`） |
| `transport: stdio` + command    | `--command <command> --args <args を , で連結>`        |
| stdio の `env`                  | `--command env --args K=V,...,<command>,<args>` で包む |
| `sbx_options`（独自キー）       | `sbx mcp add` の末尾にそのまま追加（`--dir` など）     |

- registry 参照（`io.github.xxx/yyy` 形式）は解決後のコマンドが manifest に無いため登録しません。
- remote サーバの URL にクエリ（`?toolsets=...` など）を付けると、`sbx mcp add --url` の OAuth 検出が
  「protected resource metadata resource ... does not match requested resource」で失敗します（サーバが返す
  resource はクエリ無しの URL のため）。クエリが必要なサーバは `npx -y mcp-remote@<version> <URL>` を
  stdio として登録し、OAuth は mcp-remote に任せます（クエリ中の `,` は `%2C` にエンコード）。
  例は `mcp.work3.yml.example` の datadog です。
- `sbx_options` は APM の書式に無い独自キーで、`sbx mcp add` 固有のオプションを渡すのに使います。
  例：相対パスの `--project` を使う stdio サーバに `--dir <作業ディレクトリ>`、ホストの
  `127.0.0.1` で動くサーバ（Figma デスクトップなど）に `--skip-ssrf-check`（gateway はホストから接続するため
  ループバックはホストを指しますが、sbx の SSRF チェックで拒否されます）。
- `sbx mcp add` の `--args` は `,` 区切りなので、`,` を含む引数・env はエラーにします。
- 登録した定義を `~/.local/state/sbx-mcp/<name>` に記録し、バージョンなどが変わったサーバだけ
  `sbx mcp rm` → `sbx mcp add` で登録し直します。remote サーバも定義（URL / headers）が変わると登録し直すため、
  OAuth の認可をやり直すことがあります。
- この仕組みより前に登録済みだった remote サーバは、登録し直すと認可もやり直しになるため、
  今の定義を記録するだけにします（実際に登録されている URL は確かめられないので、違う場合は
  `sbx mcp rm <name>` してから再実行します）。
- `mcp*.yml` から消したサーバは自動では消しません（OAuth トークンも消えるため）。
  `sandbox:mcp-add` が「mcp*.yml に無い登録」として表示するので、不要なら `sbx mcp rm <name>` します。
- `headers` に書いた `${VAR}` はそのまま sbx に渡り、sbx の secret（`sbx secret set`）として解決されます。

### sandbox への読み込み

`sbx-agent` は既定では MCP を**読み込みません**。使うものだけ `--static-mcp` で指定するか、
起動済みの sandbox に後から足します。

```bash
sbx-agent claude                                 # MCP なし
sbx-agent claude --static-mcp notion             # notion だけ
export SBX_AGENT_STATIC_MCP=deepwiki,context7    # 既定で読み込むものを決める
```

起動時に読み込まなかった MCP は、`mise run sandbox:mcp-load` で後から足せます。
実行すると、まず fzf で読み込む MCP を選び、その後 sandbox の MCP を全て外し（`sbx mcp unload`。sbx 0.48.0 以降）、選んだものだけを読み込み直します。
MCP の選択で何も選ばずに終了（Esc）すると、全て外すだけです。sandbox の選択で Esc を押した場合は処理を中止し、MCP は変更しません。unload 専用のタスクはありません。登録（`sbx mcp add`）は残ります。
sandbox と登録済みの MCP を fzf で選びます（MCP は Tab で複数選択。sandbox は引数でも指定可）。

```bash
mise run sandbox:mcp-load              # sandbox も fzf で選ぶ
mise run sandbox:mcp-load my-sandbox   # sandbox を指定して MCP だけ選ぶ（MCP 選択で Esc すると全て unload）
```

multi-worktree からは `[settings.sandbox].static_mcp` でも指定できます。

### 読み込みとコンテキスト

登録（`sbx mcp add`）しただけで `load` していない MCP は、agent のコンテキストを使いません。

- `sbx mcp add`（`mise run sandbox:mcp-add`）はホストの gateway に登録するだけで、どの sandbox にも割り当てません。
- sandbox から見えるのは `--static-mcp` / `sbx mcp load`（`mise run sandbox:mcp-load`）で読み込んだサーバだけです。
  `sbx-agent` も起動時に指定されたサーバを 1 つずつ `sbx mcp load ... --sandbox` しています。
  読み込んでいないサーバはツール一覧に出ないため、ツール定義のトークンも使いません。
- sandbox 内の Claude Code は template の managed settings（[上記](#エージェント自身の-mcp-設定を止める)）で
  自身の stdio MCP を起動しません。ただし共有の `~/.claude.json` にある remote（HTTP / SSE）サーバは許可リストを通るため、
  network policy で宛先が許可されていれば、gateway で `load` していなくてもツールが見えることがあります。

一度 `load` したサーバのツールは、その sandbox の agent から見えるようになります
（Claude Code は MCP ツールが多いと定義を後から読む tool search に切り替えるため、全量がそのまま載るとは限りません）。
既定で全サーバを読み込まないのはこのためで、必要なものだけ指定するか後から足します。

`unload` したサーバのツール定義は、次のターン以降コンテキストから外れます
（gateway がツール一覧の変更を `notifications/tools/list_changed` で通知し、Claude Code が一覧を取り直す前提）。
ただし次のものは残ります。

- それまでの会話履歴にあるツール呼び出しと結果。外すには `/clear` で新しく始めるか `/compact` で要約する。
- tool search で一度読み込んだツール定義（履歴の一部のため、そのセッション中は残る）。
- 共有の `~/.claude.json` にある remote サーバのツール（gateway を通らないため `unload` の対象外）。

通知が届かず古い一覧が残った場合（ツール名は見えるが呼ぶと失敗する）は、
sandbox 内で `/mcp` から再接続するか agent を起動し直します。

確かめるときは sandbox 内で `claude mcp list` と `/context` を実行し、
どのサーバ・ツールがどれだけトークンを使っているかを `load` / `unload` の前後で比べます。

### トレードオフ

`--command` で登録した stdio サーバは**ホストで動きます**。ホストの認証をそのまま使える
代わりに、MCP サーバ自体は sandbox の隔離の外にあります（ホストのファイル・ネットワーク・
認証情報に触れます）。信頼できるサーバだけを登録してください。
エージェントは gateway にしか繋がらないので、**生の認証情報は読めません**。

### devcontainer

devcontainer ではコンテナ内から MCP に接続しません。image（`Dockerfile`）に
`allowedMcpServers: []` の managed settings（`config/devcontainer/claude/mcp-policy.devcontainer.json`）を
置いているため、共有している `~/.claude.json` のサーバも読み込まれません。

## 管理ツール（CLI / TUI）

`sbx` 自身が TUI を持っています。これが唯一の専用マネージャで、現時点で lazydocker 相当の
サードパーティ製 sandbox マネージャは見つかりません。

```bash
sbx          # TUI ダッシュボード（カードで一覧 + CPU/メモリをライブ表示 + network パネル）
```

tmux からは `prefix + C-d` のツール選択（`config/tmux/tmux.conf`）に `sbx` を入れてあるので、
`lazygit`/`ghui` と同じように overlay session で開けます。

| キー    | 動作                                         |
| ------- | -------------------------------------------- |
| `c`     | 新規作成                                     |
| `s`     | 選択中の sandbox を start / stop             |
| `Enter` | agent セッションへアタッチ（`sbx run` 相当） |
| `x`     | sandbox 内でシェルを開く（`sbx exec` 相当）  |
| `r`     | 削除                                         |
| `Tab`   | Sandboxes パネルと Network パネルを切り替え  |

**lazydocker / `docker ps` では sandbox は見えません。** sandbox は microVM であって
ホストの docker daemon 上のコンテナではなく、各 sandbox が自分の docker daemon を持つためです。
`sbx` の image store もホストの image store とは別です。

- sandbox **そのもの**の管理 → `sbx` TUI、`sbx ls` / `inspect` / `stop` / `rm` / `prune`
- sandbox **の中**のコンテナ管理 → `sbx exec -it <name> docker ps` のように中から操作する。
  `lazydocker` を template に足せば `sbx exec -it <name> lazydocker` で中の daemon を見られます
- このリポジトリの運用レイヤ → `ccmanager`（セッション切り替え）と
  `multi-worktree list` / `dev`（タスク単位の起動）

## sbx の宣言的な設定と拡張機能

採用中の kit と、今後の移行候補を整理します。

### `sbxenv.yaml`（宣言的な環境定義）

`devcontainer.json` に最も近い仕組みで、workspace・追加 workspace・`env`・ports・secrets・
MCP・kits・リソース上限・ホスト側 lifecycle コマンド（`initialize` / `postCreate` / `preRemove`）を
1 ファイルで宣言できます。`~/.sbxenv.yaml` にユーザー既定を置き、
`workspace: ${{ env.projectDir }}` でプロジェクトごとに使い回すこともできます。

```yaml
schemaVersion: "1"
name: web-app
agent: claude
workspace: ./web-app
additionalWorkspaces:
  - path: ./shared-libs
    readOnly: true
env:
  AI_AGENT: "1"
secrets:
  github:
    command: gh auth token
ports:
  - sandbox: 7842
    host: 7842
sandboxOptions:
  memory: 8g
  skills: readonly
```

採用していない理由は、**`sbx env` が experimental で、かつ lifecycle コマンドや
credential command を含む plan は毎回承認が必要**なため、ccmanager から非対話で起動する
経路と相性が悪いことです（`--auto-approve` / `env.rememberHostCommands` で緩められますが、
CLI 引数の方が挙動が読めます）。安定したら移行候補です。

### kits（v3）

OCI パッケージで「workload（ベース環境とコマンド）＋ mixin（ツール・設定・認証・network 許可・
エージェント向け指示）」を合成する仕組み。devcontainer の Dockerfile + features に相当します。
今回の Claude subscription kit もこの kit の仕組みを使いますが、形式は **v2** です。
既存の組み込み `claude` を `extends: claude` で継承し、認証ヘッダーと install 処理だけを変更します。
上流の回避策が v2 で検証されているため、この PR では v3 への移行は行いません。
v3 は capabilities を使う別形式なので、`schemaVersion` だけを変えて移行することはできません。
ツール類の導入は引き続きカスタム template が担当します。
kit なら network 許可やエージェント向け指示もパッケージ化できます。
`sbx kit validate` でチェックし、kit set として publish できます。

コミット署名を自動設定する
[`git-ssh-sign`](https://github.com/docker/sbx-kits-contrib/tree/main/git-ssh-sign)
のような community kit もあります（`sbx settings set kit.allowedSources` で許可が必要）。

#### 既存設定を kit に移す候補

| 対象 | 移行の向き不向き | 理由 |
| --- | --- | --- |
| `AI_AGENT`・`TERM` など固定の環境変数 | 向いている | v2 の `environment` や v3 の対応 capability で共通化できる |
| sandbox 内の固定設定・symlink 作成 | 候補 | install / startup 処理にまとめられる。ただし mount 完了後に必要な処理や再接続時の再実行条件を検証する |
| 固定ツールセット | 配布単位としては候補 | kit で image を選べるが、mise の導入・キャッシュを使う重いビルドは template に残す方が起動時の負担が少ない |
| 固定の network 許可 | 表現可能だが現状維持 | kit 更新は sandbox 再作成が必要。現在は既存 sandbox にも反映できるホスト policy を使用 |
| Git 設定・コミット署名 | 一部候補 | 固定の Git 設定は共通化できるが、workspace ごとのメール・ホストの署名鍵選択は引き続きラッパーで判断する |
| account 別 token の読み取り・登録 | ホストに残す | sandbox 内の setup に本物の token を渡さず、ホストの secret store に登録するため |
| sandbox 名・worktree・ホストの絶対パス mount | ラッパーに残す | 起動する repository・branch・account・ホスト環境ごとに値が変わるため |
| SSH 経路・crit / plannotator の採番ポート | ラッパー中心で維持 | 作成後に決まるホスト port の取得や、再接続ごとの設定が必要 |

次に進めるなら、まず固定の環境変数を共通の mixin kit へまとめる小さい変更が候補です。
今回は認証分離の変更に限定し、これらは移していません。kit の承認は service/domain の変更時に必要で、
`sbx env` の host command を含む plan の承認とは別の仕組みです。

### その他

| 機能                       | 概要                                                                       |
| -------------------------- | -------------------------------------------------------------------------- |
| `sbx mcp`                  | MCP サーバを一度登録して gateway 経由で各 sandbox / agent から使い回す     |
| `sbx template save/load`   | sandbox のコンテナ FS を template 化して再利用（手で入れたツールを固定化） |
| `sbx mount` / `sbx umount` | 作成後に workspace を追加・削除する dynamic mount（再起動後も復元される）  |
| `sbx run --model`          | ローカル / 任意の OpenAI・Anthropic 互換エンドポイントのモデルを使う       |
| `sbx --cloud`              | Docker 管理のクラウド上で sandbox を動かす（要サブスクリプション）         |
| `sbx run --clone`          | sandbox 内の専用 clone で作業させる（main worktree からのみ利用可）        |
| `sbx diagnose`             | 環境診断（`mkfs.erofs` のブロックサイズ等まで見る）                        |

## 制限・注意点

- workspace・ports・secrets・`sandboxOptions` は **sandbox 作成時にしか確定しない**。
  変えたいときは `sbx rm` して作り直す（`sbx mount` を使えば mount だけは後から足せる）。
- `sbx exec -d` / `--detach` は **非対応**（0.45.0 で即エラーになった）。
  作成後に sandbox 内で何かを設定したい場合は前景の `sbx exec` を使うか、
  `--env` / `/etc/sandbox-persistent.sh` を使う。
- workspace の外を指すシンボリックリンクは追えない。設定ファイルは実体を渡すかコピーする。
- グローバル secret は sandbox 作成時に注入される。実行中の sandbox には後から反映されない。
- 公開ポートは stop/restart で消えるため、再起動後に `sbx ports` を打ち直す。
- `sbx run` が既存 sandbox に再アタッチする場合、`--publish` は無視される。
- sandbox 内のサービスは `127.0.0.1` ではなく `0.0.0.0` に bind させる（でないと公開ポートに届かない）。
- ラップトップをスリープさせると sandbox の時刻がずれて TLS やトークンが失敗することがある。
  `sbx stop` → `sbx run` で復旧する。
- カスタム template のビルドにはホスト側の Docker daemon が必要（sandbox 内ではビルドできない）。
- `--skills=readwrite` の sandbox は他の sandbox が読む skills を書き換えられる。
  信頼境界を分けたい場合は `--skills=off`。
- 生成物（`node_modules` / `.venv` / `target`）は worktree に書かれる。worktree は sandbox、main の
  チェックアウトはホストと持ち主を分けて運用する（[詳細](#生成物node_modules-等の扱い)）。
- `mise.toml` / `tasks/` / `lint/` / `scripts/` を変えたら `mise run sandbox:build-template` で
  template を作り直す（マウントではなく image に COPY しているため）。

## トラブルシューティング

| 症状                                                             | 対処                                                                                                                                                                                                    |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| パッケージが取得できない                                         | `sbx policy log` でブロック先を確認し `sbx policy allow network <host>` で許可                                                                                                                          |
| `You are not authenticated`                                      | `sbx login` で再認証                                                                                                                                                                                    |
| モデル API に到達できない                                        | `sbx policy allow network api.anthropic.com`。secret 登録後なら sandbox を再作成                                                                                                                        |
| ポートフォワードが効かない                                       | サービスが `0.0.0.0` に bind しているか確認し、`sbx ports` をホスト端末で実行                                                                                                                           |
| agent がホストの設定を読まない                                   | 設定ディレクトリを追加 workspace に渡し、`CLAUDE_CONFIG_DIR` 等を `--env` で明示                                                                                                                        |
| コミットが署名されない                                           | `ssh-add -L` で鍵が見えるか確認。`~/.ssh/id_ed25519.pub` があるか、別の鍵なら `SBX_AGENT_SIGNING_KEY` を設定。パスフレーズ付きなら macOS で `ssh-add --apple-use-keychain ~/.ssh/id_ed25519` を一度実行 |
| sandbox 内で git が使えない                                      | linked worktree の common git dir が渡っているか確認（relative-paths 形式は非対応）                                                                                                                     |
| 時刻ずれでトークンが失敗する                                     | `sbx stop` → `sbx run` で再起動                                                                                                                                                                         |
| crit / plannotator が `Approval required…` で起動しない          | `NO_PROXY` に `0.0.0.0` が無い。template を作り直して `sbx-agent --new`（暫定なら `NO_PROXY="$NO_PROXY,0.0.0.0" crit ...`）                                                                             |
| lint / crit が sandbox に無い                                    | `mise run sandbox:build-template` でビルドし `sbx-agent --new` で作り直す                                                                                                                               |
| ホストへの通知が飛ばない                                         | `sbx policy allow network localhost:22` と、ホスト側のリモートログイン / `authorized_keys` を確認                                                                                                       |
| 初期化スクリプトが見つからない                                   | カスタム template を使っていない。`mise run sandbox:build-template` を実行                                                                                                                              |
| `PATH` に mise の shim が無い / lint・nvim・crit が無い          | `--no-template` を付けていないか確認。付けていなければ template のビルド漏れ                                                                                                                            |
| `sbx create` が image 系のエラーで失敗する                       | template が未ビルド。下記参照                                                                                                                                                                           |
| `error: cannot run delta`                                        | ホストの gitconfig が pager に delta を指定しているため。`GIT_PAGER=cat` で無効化済み（下記）                                                                                                           |
| template のビルドが `exporting to image` で `input/output error` | Docker Desktop のディスク不足。下記参照                                                                                                                                                                 |

### `sbx create` が template を見つけられずに失敗する

`--pull missing` で渡しているため、`sbx-agent:<agent>` がローカルの image store に無いと
作成できません。`sbx-agent` は失敗時に確認手順を出します。

```console
[ERROR] sandbox の作成に失敗しました
[ERROR]   template (sbx-agent:claude) が原因かもしれません。確認するには:
[ERROR]     sbx template ls
[ERROR]   未ビルドなら: mise run sandbox:build-template claude
[ERROR]   template 無しで起動するには --no-template を付けてください
```

- `sbx template ls` に出ていないなら `mise run sandbox:build-template` を実行します。
- `error: not signed in to Docker` が出る場合は template ではなく `sbx login` の問題です
  （`sbx template ls` は未ログインだと exit 1 になります）。
- ツールチェイン無しでも急いで起動したいときは `--no-template` を付けます
  （mise / lint 群 / nvim / crit は入りません）。

### ホスト設定が参照するコマンドが sandbox に無い（`cannot run delta` 等）

`sbx-agent` はホストの gitconfig を `include.path` で取り込みます。その中には
**ホストにしか無いコマンドを指す設定**が含まれます。

```ini
[pager]
  diff = delta
  log = delta
[interactive]
  diffFilter = delta --color-only
```

`delta` は sandbox のツールチェインに入っていないため、放置すると
`git log` / `diff` / `show` が `error: cannot run delta` で失敗します。
エージェント環境では pager 自体が不要なので `sbx-agent` が無効化します。

| 上書き方法              | `pager.<cmd>` に勝てるか         |
| ----------------------- | -------------------------------- |
| `PAGER=cat`             | ❌                               |
| `core.pager=cat`        | ❌                               |
| **`GIT_PAGER=cat`**     | ✅                               |
| `pager.log=cat`（個別） | ✅（ただし項目ごとに列挙が必要） |

`pager.<cmd>` は `core.pager` や `PAGER` より強いため、それらでは上書きできません。
`GIT_PAGER` なら上書きでき、ホスト側が `pager.blame` 等を増やしても追従不要なので、
`sbx-agent` は `--env GIT_PAGER=cat` を渡します。
`interactive.diffFilter`（`git add -p` 等で使う）は env では上書きできないため、
`GIT_CONFIG_*` 側で `cat` に差し替えます。

> [!NOTE]
> `GIT_CONFIG_GLOBAL=/dev/null` では回避できません。`sbx-agent` の git 設定は
> `GIT_CONFIG_COUNT` / `GIT_CONFIG_KEY_n` / `GIT_CONFIG_VALUE_n` の**環境変数**で
> 注入しており、`GIT_CONFIG_GLOBAL` とは独立に適用されるためです。

delta のある表示を sandbox でも使いたい場合は、`config/devcontainer/mise.toml` に
`"aqua:dandavison/delta"` を追加して template を作り直し、上記の無効化を外してください。

#### `credential.helper` も同じ問題を持つ

同じ理由で、ホストの `credential.helper = osxkeychain`（macOS 用）は Linux の
sandbox には存在しません。

ここで注意が必要なのは、**URL 限定の helper は generic な helper を置き換えるのではなく、
リストに追加される**という点です。つまり `credential.https://github.com.helper` に
`!gh auth git-credential` を設定しても、github.com 向けの解決では
`osxkeychain` → `gh` の順に試され、**毎回エラーが出てから** `gh` にたどり着きます。

```console
$ git credential fill   # generic osxkeychain + URL 限定 gh
git: 'credential-osxkeychain' is not a git command. See 'git --help'.
...
```

そこで、URL 限定の helper に**空文字を先に入れてリストをリセット**してから `gh` を足します。

```bash
add_git_config 'credential.https://github.com.helper' ''
add_git_config 'credential.https://github.com.helper' '!gh auth git-credential'
```

devcontainer 側（`post-create.sh`）は `git config` で同じ状態を作ります。

```bash
git config --global --replace-all credential.https://github.com.helper ""
git config --global --add credential.https://github.com.helper '!gh auth git-credential'
```

> [!NOTE]
> `GIT_CONFIG_VALUE_n` が欠けても git は fatal にならないため、空の値が環境変数として
> 渡らない環境でも現状より悪化はしません（リセットが効かずエラーが出るだけ）。

**GitHub 以外の HTTPS git host**（社内 GitLab 等）については、リセットの対象が
github.com 限定なので `osxkeychain` の解決に失敗したままです。必要になったら
generic な `credential.helper` 側もリセットしてください。

### template のビルドが `exporting to image` で失敗する

全ステップが成功したあと、最後の `exporting to image` だけが

```
ERROR: failed to build: failed to solve: failed to extract layer sha256:...:
write /var/lib/desktop-containerd/daemon/.../snapshots/566/fs/mise/data/installs/...:
input/output error
```

で失敗する場合、**Dockerfile の問題ではなく Docker Desktop のディスク不足**です。
`/var/lib/desktop-containerd` は Docker Desktop の VM 内なので、仮想ディスクが上限に
達すると `ENOSPC` ではなく `input/output error` として現れることがあります。

この template はツールチェイン一式（`core:go` / `node` / `python` / `bun` ＋ lint 群）が
入るため数 GB になります。対処は次の順で。

1. `docker system df` で使用量を確認する
2. `docker image prune -a` / `docker container prune` で空ける
3. Docker Desktop の Settings > Resources > **Disk usage limit** を増やす
4. それでも直らなければ仮想ディスクの破損を疑う（Troubleshoot > Clean / Purge data）

> [!WARNING]
> `docker builder prune` でも空きますが、`Dockerfile.sandbox` が使っている
> **mise のインストール済みツールの cache mount も消えます**。
> 次回のビルドは初回と同じフルインストール（数百秒）になります。

`docker image save` が書く tar も数 GB になるため、`$TMPDIR`（macOS では
`/var/folders/...`）側にも同等の空きが必要です。足りない場合は `TMPDIR` を
空きのあるパスに向けて実行してください。

## 参考

- [Docker Sandboxes（製品ページ）](https://www.docker.com/products/docker-sandboxes/)
- [Docker Sandboxes ドキュメント](https://docs.docker.com/ai/sandboxes/)
- [リリースノート](https://docs.docker.com/ai/sandboxes/release-notes/) / [docker/sbx-releases](https://github.com/docker/sbx-releases)
- [sbx CLI リファレンス](https://docs.docker.com/reference/cli/sbx/)
- [環境ファイル（`sbxenv.yaml`）](https://docs.docker.com/ai/sandboxes/configuration/environment-files/)
- [kits（カスタマイズ）](https://docs.docker.com/ai/sandboxes/customize/)
- [docs/multi-worktree.md](multi-worktree.md) - multi-worktree との統合
- [docs/devcontainer.md](devcontainer.md) - 旧バックエンド（devcontainer）の仕組み
