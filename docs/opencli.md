# OpenCLI

[OpenCLI](https://github.com/jackwener/OpenCLI) は、Web サイトやログイン済みブラウザセッションを
CLI に変換し、人間と AI エージェントの両方から Web 操作（ページ遷移・フォーム入力・クリック・
データ抽出など）を自動化できるツール。ログイン済みの Chrome セッションを介して動くため、認証が
必要なサイトでもそのまま操作できるのが特徴。

## 導入

### CLI 本体（mise 管理）

`opencli` コマンド本体は npm パッケージ [`@jackwener/opencli`](https://www.npmjs.com/package/@jackwener/opencli)
で、この dotfiles では mise の `[tools]` に登録済み。

- ホスト用（グローバル）: `dot_config/mise/config.toml`
- devcontainer 用: `dot_config/devcontainer/mise.toml`（コンテナイメージにも同梱される）

```toml
"npm:@jackwener/opencli" = "1.8.6"
```

- Node.js >= 20 が前提。`core:node` を mise が入れているので追加対応は不要
- `mise install` で他ツールと一緒に導入される
- 手動でグローバル導入したい場合は下記でも可（mise 管理を使うなら不要）
  ```sh
  npm install -g @jackwener/opencli
  ```

> [!NOTE]
> このリポジトリの想定構成は「**AI（`opencli` CLI とエージェント）は devcontainer 内**、
> **ブラウザはホスト側**」。そのための追加設定は下記
> [devcontainer 構成（AI はコンテナ、ブラウザはホスト）](#devcontainer-構成ai-はコンテナブラウザはホスト)
> にまとめている。ホスト単体でそのまま使う場合はこの節は読み飛ばしてよい。

### ブラウザ連携（Browser Bridge）

CLI 本体だけではブラウザ操作系のコマンドは動かない。ログイン済み Chrome とやり取りするために、
以下いずれかのブリッジをセットアップする。

- **Browser Bridge 拡張**: Chrome Web Store から「OpenCLI Browser Bridge」拡張を導入して有効化する
  （手動で入れる場合は `chrome://extensions` で GitHub の unpacked release を読み込む）
- **OpenCLIApp（デスクトップ、推奨）**: <https://opencli.info/download> からダウンロードして導入。
  アプリの System ページから `opencli` コマンドのセットアップも行える

導入後、疎通確認する。

```sh
opencli doctor
```

## 初期セットアップ

`doctor` で環境を確認したら、ブラウザプロファイルを設定する。

```sh
opencli doctor                       # 環境・ブリッジの状態チェック
opencli profile list                 # 認識されているブラウザプロファイル一覧
opencli profile rename <contextId> work   # プロファイルにエイリアスを付ける
opencli profile use work             # 使用プロファイルを選択
opencli list                         # 利用可能なコマンド（アダプタ）一覧
```

## 基本的な使い方

書式は `opencli <site> <command> [options]`。

```sh
opencli hackernews top --limit 5     # HackerNews のトップ記事
opencli bilibili hot --limit 5       # Bilibili の急上昇動画
opencli list                         # 対応サイト・コマンドの一覧を確認
```

Xiaohongshu・Bilibili・Twitter/X・Reddit・HackerNews など 100 以上のサイトにビルトインで対応。

### 出力フォーマット

すべてのコマンドは `--format` / `-f` で出力形式を切り替えられる。既定は `table`。

| 値      | 内容        |
| ------- | ----------- |
| `table` | 表形式（既定） |
| `json`  | JSON        |
| `yaml`  | YAML        |
| `md`    | Markdown    |
| `csv`   | CSV         |

```sh
opencli bilibili hot -f json
opencli bilibili hot -f csv
```

### ブラウザ操作コマンド

`opencli browser <session> <op>` で、ログイン済みブラウザを直接操作する。

```sh
opencli browser <session> open <url>       # URL を開く
opencli browser <session> click <selector> # 要素をクリック
opencli browser <session> type <text>      # テキスト入力
opencli browser <session> extract          # データ抽出
```

利用できる主な操作: `open` / `state` / `click` / `type` / `fill` / `select` / `keys` / `wait` /
`get` / `find` / `extract` / `frames` / `screenshot` / `scroll` / `back` / `eval` / `network` /
`tab list` / `tab new` / `tab select` / `tab close` / `init` / `verify` / `close`

### ダウンロード

Xiaohongshu・Bilibili・Twitter・Douban・Pixiv・1688 などからのダウンロードに対応（動画は
`yt-dlp` が別途必要）。

```sh
opencli xiaohongshu download "<url>" --output ./xhs
opencli bilibili download BV1xxx --output ./bilibili
```

## AI エージェント連携（skills）

Claude / Cursor などの AI エージェントに OpenCLI のブラウザ操作スキルを追加できる。

```sh
npx skills add jackwener/opencli
```

個別スキルの追加:

```sh
npx skills add jackwener/opencli --skill opencli-browser         # ページ遷移・入力・抽出
npx skills add jackwener/opencli --skill opencli-adapter-author  # 新規サイトアダプタの作成
npx skills add jackwener/opencli --skill opencli-autofix         # 壊れたアダプタの修復
```

導入すると、エージェントが navigate / click / type / extract / wait などのブラウザプリミティブを
プロンプトの手動指示なしに利用できるようになる。

## devcontainer 構成（AI はコンテナ、ブラウザはホスト）

このリポジトリでは、AI エージェントと `opencli` CLI は **devcontainer 内**で動かし、実際の
ブラウザ（ログイン済み Chrome）は **ホスト側**で動かす構成を想定している。

### なぜトンネルが要るのか

OpenCLI の daemon は **ホストの `127.0.0.1:19825` に固定バインド**される（ポート変更は不可＝
`OPENCLI_DAEMON_PORT` は廃止済み、バインド先も loopback 固定）。ホストの Chrome 拡張
（Browser Bridge）はこの daemon とだけ通信し、`opencli` CLI も**自分の `localhost:19825`**に
繋ぎに行く実装になっている。つまりコンテナ内の CLI からホストのブラウザを操作するには、
コンテナの `localhost:19825` をホストの daemon へ橋渡しする必要がある。

daemon は**認証を持たない**（繋げた相手は全 Cookie の読み取り・任意 JS 実行が可能）。そのため
ポートを直接ネットワークに公開してはならず、OpenCLI 公式も
[reverse tunnel 方式](https://github.com/jackwener/OpenCLI/blob/main/docs/guide/remote-orchestration.md)
を推奨している。このリポジトリでは既存の devcontainer → ホスト SSH（`mac-host`）を再利用して
SSH ローカルフォワードで橋渡しする。

```
┌─ ホスト(mac) ─────────────────────────────┐        ┌─ devcontainer ───────────┐
│  Chrome ↔ Browser Bridge拡張 ↔ daemon      │        │  AI エージェント          │
│                        (127.0.0.1:19825)   │ ◀──┐   │  + opencli CLI            │
└────────────────────────────────────────────┘    │   │  (localhost:19825 に接続) │
                              SSH ローカルフォワード ┘   └───────────────────────────┘
                              ssh -L 127.0.0.1:19825:127.0.0.1:19825 mac-host
```

### 設定済みの内容（このリポジトリ）

- **CLI をコンテナに同梱**: `dot_config/devcontainer/mise.toml` に
  `"npm:@jackwener/opencli"` を追加済み（イメージビルド時に `mise install` される）
- **トンネルの自動起動**: `dot_config/devcontainer/scripts/executable_post-start.sh` が、
  コンテナ起動時に `mac-host` へ SSH ローカルフォワードを張る
  （`localhost:19825` → ホスト daemon）。既存の `mac-host` SSH 設定・鍵をそのまま流用し、
  多重起動を避けるため既存トンネルがあればスキップ、`mac-host` に繋がらない環境でもスキップする
  （非致命）

コンテナ内の `opencli` は**フラグも環境変数も不要**で、自分の `localhost:19825` に繋ぐだけで
ホストのブラウザを操作できる。

### ホスト側の準備

トンネルの宛先になるホスト daemon が動いている必要がある。

- [ ] **OpenCLIApp か Chrome + Browser Bridge 拡張がホストで起動している**
      （＝ daemon が `127.0.0.1:19825` で待ち受けている状態。`opencli` 使用中は Chrome を
      開いたままにする）
- [ ] **ホストの SSH（Remote Login）が有効**で、devcontainer から `mac-host` に繋がる
      （crit 等の既存 devcontainer 連携と同じ前提。`docs/devcontainer.md` / `docs/crit.md` 参照）

### 動作確認

コンテナ内で以下を実行する。

```sh
# トンネル越しにホストの daemon が見えているか
curl -sf http://127.0.0.1:19825/ping && echo "daemon reachable"

# 拡張バージョン等の疎通確認（ホストの Chrome と同じ拡張バージョンが表示されれば OK）
opencli doctor

# 実際にホストのブラウザを操作
opencli browser open https://example.com
```

### うまく動かないとき

- `daemon reachable` にならない / `opencli` が「no daemon」で失敗する
  - ホストで Chrome（＋ Browser Bridge）または OpenCLIApp が起動しているか確認する
    （Chrome を閉じると daemon への接続が切れる）
  - トンネルが張れているか確認する: `pgrep -af 'ssh.*-L 127.0.0.1:19825'`
  - 手動でトンネルを張り直す:
    ```sh
    ssh -F ~/.config/ssh/config -N \
      -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
      -L 127.0.0.1:19825:127.0.0.1:19825 mac-host &
    ```
    （または `bash ~/.config/devcontainer/scripts/post-start.sh` を再実行）
- `mac-host` に繋がらない → ホストの SSH 有効化・鍵（`id_docker_devcontainer`）の配置を確認する
  （`docs/devcontainer.md` 参照）
- トンネルはあくまで loopback 間の SSH 経由。daemon ポートを `0.0.0.0` 公開したり frp 等で
  直接晒したりしないこと（認証が無いため危険）

## 設定（環境変数）

| 変数                              | 既定値           | 用途                                  |
| --------------------------------- | ---------------- | ------------------------------------- |
| `OPENCLI_PROFILE`                 | —                | 使用するブラウザプロファイルのエイリアス |
| `OPENCLI_WINDOW`                  | コマンド既定     | ウィンドウ配置 `foreground` / `background` |
| `OPENCLI_BROWSER_CONNECT_TIMEOUT` | `45`             | 接続待ち時間（秒）                    |
| `OPENCLI_BROWSER_COMMAND_TIMEOUT` | `60`             | コマンド待ち時間（秒）                |
| `OPENCLI_CDP_ENDPOINT`            | —                | リモートブラウザ / Electron の CDP エンドポイント |
| `OPENCLI_CDP_TARGET`              | —                | CDP ターゲット URL のフィルタ         |
| `OPENCLI_VERBOSE`                 | `false`          | 詳細ログ（`-v` でも可）               |

## アダプタの拡張

新しいサイト用のアダプタを作成・導入できる。

```sh
opencli plugin create                       # プラグインの雛形を作成
opencli plugin install file://...           # ローカルからインストール
opencli plugin install github:user/repo     # GitHub からインストール
opencli adapter eject <site>                # 既存アダプタを取り出して編集
opencli external register <name>            # 外部ツールを登録
```

## 終了コード

| コード | 意味                       |
| ------ | -------------------------- |
| `0`    | 成功                       |
| `66`   | 結果が空                   |
| `69`   | Browser Bridge が停止      |
| `75`   | タイムアウト               |
| `77`   | 認証が必要                 |
| `78`   | 設定エラー                 |
| `130`  | 中断（Ctrl-C）             |

## トラブルシューティング

- ブラウザ操作が動かない → Chrome の拡張（Browser Bridge）が導入・有効化されているか確認する
- デーモンの状態確認: `curl localhost:19825/status`
- 「Unauthorized」が返る → 対象サイトのログインセッションを更新する
- コマンドが見つからない → `mise install` 済みか、Node.js >= 20 が有効かを確認する（`opencli doctor`）
