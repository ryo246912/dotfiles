# OpenCLI

[OpenCLI](https://github.com/jackwener/OpenCLI) は、Web サイトやログイン済みブラウザセッションを
CLI に変換し、人間と AI エージェントの両方から Web 操作（ページ遷移・フォーム入力・クリック・
データ抽出など）を自動化できるツール。ログイン済みの Chrome セッションを介して動くため、認証が
必要なサイトでもそのまま操作できるのが特徴。

## 導入

### CLI 本体（mise 管理）

`opencli` コマンド本体は npm パッケージ [`@jackwener/opencli`](https://www.npmjs.com/package/@jackwener/opencli)
で、この dotfiles では mise の `[tools]` に登録済み（`dot_config/mise/config.toml`）。

```toml
"npm:@jackwener/opencli" = "1.8.6"
```

- Node.js >= 20 が前提。`core:node` を mise が入れているので追加対応は不要
- `mise install` で他ツールと一緒に導入される
- 手動でグローバル導入したい場合は下記でも可（mise 管理を使うなら不要）
  ```sh
  npm install -g @jackwener/opencli
  ```

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
