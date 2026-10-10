# Playwright CLI コマンドリファレンス

`@playwright/cli` (npm) の公式コマンド一覧。Docker 経由で実行する場合のプレフィックス:

```bash
docker compose exec playwright playwright-cli <command> [options]
```

ローカル実行の場合は `playwright-cli <command>` または `npx playwright-cli <command>`。

## open コマンド（起動）

```bash
playwright-cli open [url]                    # ブラウザを開く（ヘッドレス）
playwright-cli open <url> --headed           # ヘッド付きで開く（デフォルトはヘッドレス）
playwright-cli open --browser=chrome         # ブラウザ指定（chrome/firefox/webkit/msedge）
playwright-cli open --persistent             # 永続プロファイルを使用
playwright-cli open --profile=<path>         # カスタムプロファイルディレクトリ
playwright-cli open --extension              # ブラウザ拡張経由で接続
playwright-cli open --config=file.json       # 設定ファイルを使用
```

## セッション管理

```bash
playwright-cli -s=<name> <command>           # 名前付きセッションでコマンド実行
playwright-cli list                          # 全セッション一覧
playwright-cli close                         # 現在のページを閉じる
playwright-cli close-all                     # 全ブラウザを閉じる
playwright-cli kill-all                      # 全ブラウザプロセスを強制終了
playwright-cli delete-data                   # デフォルトセッションのユーザーデータ削除
playwright-cli -s=<name> delete-data         # 名前付きセッションのデータ削除
playwright-cli show                          # ビジュアルダッシュボードを開く
```

環境変数 `PLAYWRIGHT_CLI_SESSION=<name>` でデフォルトセッション名を指定可能。

## ページ遷移

```bash
playwright-cli goto <url>                    # URL に遷移
playwright-cli go-back                       # 前のページに戻る
playwright-cli go-forward                    # 次のページに進む
playwright-cli reload                        # ページをリロード
```

## 要素操作

`<ref>` は snapshot の YAML に含まれる要素リファレンス ID（例: `e15`, `e21`）。

```bash
playwright-cli click <ref> [button]          # クリック（button: left/right/middle）
playwright-cli dblclick <ref> [button]       # ダブルクリック
playwright-cli hover <ref>                   # ホバー
playwright-cli fill <ref> <text>             # 入力欄にテキストを設定（既存値をクリア）
playwright-cli type <text>                   # フォーカス中の要素にキーストローク入力
playwright-cli select <ref> <value>          # ドロップダウンの選択
playwright-cli check <ref>                   # チェックボックス/ラジオボタン ON
playwright-cli uncheck <ref>                 # チェックボックス OFF
playwright-cli upload <file>                 # ファイルアップロード
playwright-cli drag <startRef> <endRef>      # ドラッグ＆ドロップ
playwright-cli resize <width> <height>       # ブラウザウィンドウのリサイズ
```

## キーボード

```bash
playwright-cli press <key>                   # キー押下（例: Enter, Tab, Escape, ArrowLeft）
playwright-cli keydown <key>                 # キーダウン
playwright-cli keyup <key>                   # キーアップ
```

## マウス

```bash
playwright-cli mousemove <x> <y>             # マウス移動
playwright-cli mousedown [button]            # マウスボタンダウン
playwright-cli mouseup [button]              # マウスボタンアップ
playwright-cli mousewheel <dx> <dy>          # スクロール（正:下/右、負:上/左）
```

## スナップショット・スクリーンショット

各コマンド実行後、自動的にスナップショット（アクセシビリティツリーYAML）が出力される。

```bash
playwright-cli snapshot                      # スナップショットを取得（自動ファイル名）
playwright-cli snapshot --filename=<path>    # 指定パスに保存
playwright-cli screenshot                    # スクリーンショット（自動ファイル名）
playwright-cli screenshot [ref]              # 特定要素のスクリーンショット
playwright-cli screenshot --filename=<path>  # 指定パスに保存
playwright-cli pdf                           # PDF出力（自動ファイル名）
playwright-cli pdf --filename=<path>         # 指定パスに保存
```

スナップショットは `.playwright-cli/` ディレクトリに YAML ファイルとして保存される。`--filename` 未指定時はタイムスタンプ付き自動命名。

## JavaScript 実行

```bash
playwright-cli eval <expression>             # JS式を評価（ページ上）
playwright-cli eval <expression> <ref>       # 特定要素上で JS 式を評価
playwright-cli run-code <code>               # Playwright コードスニペットを実行
```

## コンソール・ネットワーク

```bash
playwright-cli console                       # コンソールメッセージ一覧
playwright-cli console error                 # エラーレベル以上のみ（error/warning/info/debug）
playwright-cli network                       # ページ読み込み以降の全ネットワークリクエスト一覧
```

## タブ管理

```bash
playwright-cli tab-list                      # タブ一覧
playwright-cli tab-new [url]                 # 新しいタブを開く
playwright-cli tab-close [index]             # タブを閉じる（インデックス指定可）
playwright-cli tab-select <index>            # タブを切り替え
```

## ダイアログ処理

```bash
playwright-cli dialog-accept [prompt]        # ダイアログを承認（prompt 入力テキスト指定可）
playwright-cli dialog-dismiss                # ダイアログを拒否
```

## ストレージ操作

```bash
# ブラウザ状態
playwright-cli state-save [filename]         # ストレージ状態を保存
playwright-cli state-load <filename>         # ストレージ状態を読み込み

# Cookie
playwright-cli cookie-list [--domain]        # Cookie 一覧（ドメインでフィルタ可）
playwright-cli cookie-get <name>             # Cookie 取得
playwright-cli cookie-set <name> <value>     # Cookie 設定
playwright-cli cookie-delete <name>          # Cookie 削除
playwright-cli cookie-clear                  # 全 Cookie クリア

# localStorage
playwright-cli localstorage-list             # 一覧
playwright-cli localstorage-get <key>        # 取得
playwright-cli localstorage-set <key> <val>  # 設定
playwright-cli localstorage-delete <key>     # 削除
playwright-cli localstorage-clear            # 全クリア

# sessionStorage
playwright-cli sessionstorage-list           # 一覧
playwright-cli sessionstorage-get <key>      # 取得
playwright-cli sessionstorage-set <key> <val> # 設定
playwright-cli sessionstorage-delete <key>   # 削除
playwright-cli sessionstorage-clear          # 全クリア
```

## ネットワーク制御

```bash
playwright-cli route <pattern> [opts]        # リクエストモック（パターンマッチ）
playwright-cli route-list                    # アクティブなルート一覧
playwright-cli unroute [pattern]             # ルート解除
```

## トレース・録画

```bash
playwright-cli tracing-start                 # トレース記録開始
playwright-cli tracing-stop                  # トレース記録停止（出力ディレクトリに保存）
playwright-cli video-start                   # 動画録画開始
playwright-cli video-stop [filename]         # 動画録画停止（ファイル名指定可）
```

## 設定ファイル

`.playwright/cli.config.json` に配置すると自動読み込みされる。`--config` で明示指定も可能。

```json
{
  "browser": {
    "browserName": "chromium",
    "isolated": true,
    "launchOptions": { "headless": true },
    "contextOptions": { "viewport": { "width": 1280, "height": 720 } }
  },
  "outputDir": "./tmp/webtest",
  "outputMode": "file",
  "console": { "level": "error" },
  "network": {
    "allowedOrigins": ["https://myapp.example.com"],
    "blockedOrigins": []
  },
  "timeouts": {
    "action": 5000,
    "navigation": 60000
  }
}
```

## dev-webtest で使う主要パターン

### ページアクセスとスナップショット取得

```bash
playwright-cli open http://app:8080/login
playwright-cli snapshot
```

### ログインフロー

```bash
playwright-cli open http://app:8080/login
playwright-cli snapshot                          # ref ID を確認
playwright-cli fill e15 "user@example.com"
playwright-cli fill e18 "password123"
playwright-cli click e21
playwright-cli snapshot                          # ログイン後の状態確認
```

### レスポンシブ確認

```bash
# モバイル
playwright-cli open http://app:8080 --config=mobile.json
playwright-cli screenshot --filename=/work/tmp/webtest/screenshots/mobile.png

# タブレット（resize で切り替え）
playwright-cli resize 768 1024
playwright-cli screenshot --filename=/work/tmp/webtest/screenshots/tablet.png

# デスクトップ
playwright-cli resize 1280 800
playwright-cli screenshot --filename=/work/tmp/webtest/screenshots/desktop.png
```

### フォームバリデーション確認

```bash
playwright-cli open http://app:8080/form
playwright-cli snapshot                          # フォーム構造と ref 確認
playwright-cli click e30                         # 空のまま送信
playwright-cli snapshot                          # バリデーションエラー確認
playwright-cli console error                     # JS エラー確認
```

### エラー検出（モンキーテスト向け）

```bash
playwright-cli snapshot                          # 操作対象を把握
playwright-cli click e12                         # ランダム操作
playwright-cli console error                     # JS エラー確認
playwright-cli network                           # HTTP エラー確認
playwright-cli screenshot --filename=/work/tmp/webtest/screenshots/error.png
```

## 注意事項

- `<ref>` は snapshot YAML 内の要素 ID。操作前に必ず `snapshot` で最新の ref を取得する
- Docker 内ではヘッドレスがデフォルト。`--headed` はローカル確認用
- スクリーンショットのパスは Docker ボリュームマウント先（`/work/` 配下）を指定する
- 各コマンド実行後に自動でスナップショットが返される（コンテキスト管理に注意）
- セッション名 (`-s=name`) で複数ブラウザを並行操作可能
