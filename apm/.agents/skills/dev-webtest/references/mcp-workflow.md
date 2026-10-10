# MCP モードワークフロー

`@playwright/mcp` を MCP サーバーとして利用する場合のワークフロー。`@playwright/cli` が利用できない場合のフォールバック手段。

## CLI → MCP ツール対応表

| CLI コマンド | MCP ツール | 備考 |
|-------------|-----------|------|
| `open <url> --headless` | `browser_navigate` | URL遷移。ブラウザは自動起動 |
| `close` | `browser_close` | ブラウザを閉じる |
| `goto <url>` | `browser_navigate` | `open` と同じツール |
| `go-back` | `browser_go_back` | |
| `go-forward` | `browser_go_forward` | |
| `reload` | — | `browser_navigate` で同一URLを再指定 |
| `click <ref>` | `browser_click` | `element` パラメータに説明テキストを指定 |
| `hover <ref>` | `browser_hover` | |
| `fill <ref> "value"` | `browser_type` | `text` パラメータに入力値を指定 |
| `type "text"` | `browser_type` | |
| `press <key>` | `browser_press_key` | `key` パラメータにキー名を指定 |
| `drag <from> <to>` | `browser_drag` | |
| `select <ref> "value"` | `browser_select_option` | |
| `upload <ref> <file>` | `browser_file_upload` | `paths` パラメータにファイルパス配列 |
| `snapshot` | `browser_snapshot` | レスポンスに直接アクセシビリティツリーが返る |
| `screenshot` | `browser_take_screenshot` | base64 画像が直接返る（ファイル保存なし） |
| `pdf` | `browser_pdf_save` | |
| `eval "js"` | `browser_evaluate` | JavaScript 実行 |
| `console` | `browser_console_messages` | |
| `network` | `browser_network_requests` | |
| `tab-list` | `browser_tab_list` | |
| `tab-new <url>` | `browser_tab_new` | |
| `tab-close` | `browser_tab_close` | |
| `tab-select <id>` | `browser_tab_select` | |
| `dialog-accept` | `browser_handle_dialog` | `accept: true` |
| `dialog-dismiss` | `browser_handle_dialog` | `accept: false` |
| `open ... --viewport WxH` | `browser_resize` | navigate 後に別途リサイズ |

## CLI との主な違い

| 項目 | CLI モード | MCP モード |
|------|-----------|-----------|
| **実行方式** | `docker compose exec` + Bash | MCP プロトコル経由のツール呼び出し |
| **スクリーンショット** | ファイル保存 → Read tool で読み取り | base64 が直接レスポンスに含まれる |
| **スナップショット** | YAML ファイル保存 + stdout | レスポンスにアクセシビリティツリーが直接返る |
| **ビューポート制御** | `--viewport WxH` フラグで open 時に指定 | `browser_resize` で navigate 後に変更 |
| **要素指定** | ref ID（`e15` 等） | 要素の説明テキスト（`"Login button"` 等） |
| **セッション管理** | `-s=name` で名前付きセッション | 単一セッション（複数セッション非対応） |
| **ブラウザ起動** | `open` で明示的に起動 | 初回 navigate 時に自動起動 |

### 重要な注意点

- **要素指定方法が異なる**: CLI では `snapshot` の ref ID（例: `e15`）を使うが、MCP では要素の説明テキスト（例: `"Email input field"`）を使う。`browser_snapshot` の結果から適切な説明を読み取ること
- **スクリーンショットはファイル保存されない**: `browser_take_screenshot` は base64 を返すため、Read tool での読み取りは不要。Claude が直接画像を解析する
- **ビューポート変更は2ステップ**: まず `browser_navigate` でページを開き、次に `browser_resize` でサイズを変更する

## MCP 版ワークフロー

SKILL.md の各 Step を MCP ツールで実行する手順。

### Step 1: 環境準備

MCP モードには Docker MCP とローカル MCP の2形態がある。SKILL.md の Step 1 で選択された形態に従う。

| 形態 | MCP サーバーの起動方法 | テスト対象 URL |
|------|----------------------|---------------|
| Docker MCP | コンテナ内で `@playwright/mcp` を起動、SSE 接続 | `http://app:<port>` |
| ローカル MCP | npx 経由でローカル起動（`.mcp.json`） | `http://localhost:<port>` |

1. MCP サーバーの接続を確認する
   - `browser_navigate` で対象 URL にアクセスし、正常にレスポンスが返ることを確認
2. 接続できない場合:
   - Docker MCP → `references/docker-setup.md` の「`@playwright/cli` が存在しない場合のフォールバック」セクションを確認
   - ローカル MCP → `references/docker-setup.md` の「ローカル MCP セットアップ」セクションを確認

### Step 2: テスト実行

#### 2a: 計画テスト

1. テスト計画ファイルを読み込む
2. 各シナリオを順番に実行:
   - `browser_navigate` で URL にアクセス
   - `browser_snapshot` で要素を確認
   - `browser_click`, `browser_type` 等で操作
   - 各ステップで `browser_snapshot` を取得して状態確認
   - 視覚チェックポイントで `browser_take_screenshot` を取得
3. 結果を記録する

#### 2b: モンキーテスト

1. `browser_navigate` で指定 URL にアクセス
2. `browser_snapshot` でページ構造を把握
3. ランダムアクションを実行（最大20回）:
   - `browser_click` でリンク・ボタンをクリック
   - `browser_type` でフォームにランダム入力
   - `browser_go_back` / `browser_go_forward` でナビゲーション
4. 各アクション後:
   - `browser_snapshot` でページ状態を取得
   - `browser_console_messages` で JS エラーを確認
   - `browser_network_requests` で HTTP エラーを確認
5. 問題検出時は `browser_take_screenshot` を取得

#### 2c: クイックチェック

1. `browser_navigate` で指定 URL にアクセス
2. `browser_take_screenshot` + `browser_snapshot` を取得
3. 視覚チェックとアクセシビリティチェックのみ実行

### Step 3: 視覚チェック

`browser_take_screenshot` の base64 画像を Claude が直接解析する。ファイル保存・Read tool は不要。**判定完了後は画像の内容をテキスト要約に変換し、以降はテキスト要約のみ保持する**（SKILL.md のコンテキスト管理ルール参照）。

### Step 4: アクセシビリティチェック

`browser_snapshot` のレスポンスを直接分析する。CLI と同じチェック項目を適用。**snapshot の YAML 全体を保持せず、判定に必要な要素のみ抽出する**（SKILL.md のコンテキスト管理ルール参照）。

キーボード操作テストは `browser_press_key` で `Tab` キーを押下して確認する。各 Tab 後はフォーカス要素名のみを記録する。

### Step 5: レスポンシブテスト

```
# モバイル
browser_navigate → <url>
browser_resize → width: 375, height: 667
browser_take_screenshot → 判定後テキスト要約に変換

# タブレット
browser_resize → width: 768, height: 1024
browser_take_screenshot → 判定後テキスト要約に変換

# デスクトップ
browser_resize → width: 1280, height: 800
browser_take_screenshot → 判定後テキスト要約に変換
```

**注意**: MCP モードでは同一セッションで `browser_resize` を使いビューポートを切り替える。CLI のように毎回 open/close する必要はない。各スクリーンショットの判定完了後は base64 画像を保持せず、テキスト要約のみ保持する。

### Step 6: フォームバリデーションテスト

CLI モードと同じテストパターンを適用。操作コマンドのみ MCP ツールに置き換える:

- `fill` → `browser_type`
- `click` → `browser_click`
- `snapshot` → `browser_snapshot`
- `screenshot` → `browser_take_screenshot`

### Step 7: 問題の修正

CLI モードと同じ。修正対象はソースコードなので差異なし。

### Step 8: レポート出力

CLI モードと同じ。レポートフォーマットに差異なし。

## よく使うパターン

### ログインフロー

```
browser_navigate → url: "http://localhost:8080/login"
browser_snapshot                                        # フォーム要素を確認
browser_type → element: "Email input", text: "user@example.com"
browser_type → element: "Password input", text: "password123"
browser_click → element: "Login button"
browser_snapshot                                        # ログイン後の状態確認
browser_take_screenshot                                 # スクリーンショット取得
```

### レスポンシブ確認

```
browser_navigate → url: "http://localhost:8080"

# モバイル
browser_resize → width: 375, height: 667
browser_take_screenshot

# タブレット
browser_resize → width: 768, height: 1024
browser_take_screenshot

# デスクトップ
browser_resize → width: 1280, height: 800
browser_take_screenshot
```

### フォームバリデーション確認

```
browser_navigate → url: "http://localhost:8080/form"
browser_snapshot                                        # フォーム構造確認
browser_click → element: "Submit button"                # 空のまま送信
browser_snapshot                                        # バリデーションエラー確認
browser_take_screenshot
```

## 未対応コマンド

以下の CLI コマンドは MCP モードに対応するツールがない。これらの機能が必要な場合は CLI モードを使用する。

| CLI コマンド | 用途 | 代替手段 |
|-------------|------|---------|
| `tracing-start` / `tracing-stop` | パフォーマンストレース | Chrome DevTools MCP の利用を検討 |
| `video-start` / `video-stop` | 動画録画 | スクリーンショットの連続取得で代替 |
| `cookie-list` / `cookie-set` / `cookie-clear` | Cookie 操作 | `browser_evaluate` で `document.cookie` を操作 |
| `localstorage-get` / `localstorage-set` / `localstorage-clear` | localStorage 操作 | `browser_evaluate` で `localStorage` API を操作 |
| `state-save` / `state-load` | ブラウザ状態の保存・復元 | なし |
| `route` / `unroute` / `route-list` | ネットワークインターセプト | なし |
| `list` / `close-all` | セッション管理 | MCP は単一セッション |
| `-s=name` | 名前付きセッション | MCP は単一セッション |
| `dblclick` | ダブルクリック | `browser_click` を2回実行（完全な代替ではない） |
| `check` / `uncheck` | チェックボックス操作 | `browser_click` で代替 |
| `keydown` / `keyup` | キー押下・解放 | `browser_press_key` で代替（修飾キーの保持は不可） |
| `mousewheel` | スクロール | `browser_evaluate` で `window.scrollBy()` を実行 |
| `mousemove` | マウス移動 | なし |
