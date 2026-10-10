# Docker 環境セットアップ

dev-webtest スキル用の Playwright 実行環境をセットアップする手順。

## 前提

- Docker Compose でアプリケーションが動作していること
- `docker compose up -d` でアプリが起動済みであること

## セットアップ手順

### Step 1: docker-compose.yaml に Playwright サービスを追加

```yaml
  playwright:
    image: mcr.microsoft.com/playwright:v1.50.0-noble
    working_dir: /work
    volumes:
      - .:/work
    depends_on:
      - app
    command: ["tail", "-f", "/dev/null"]
    environment:
      - PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
```

**ポイント**:
- `mcr.microsoft.com/playwright` は Chromium/Firefox/WebKit がプリインストールされた公式イメージ
- `volumes: .:/work` でプロジェクトルートをマウント（スクリーンショットの共有用）
- `command: tail -f /dev/null` でコンテナを起動状態に保つ
- `depends_on: app` でアプリ起動後に Playwright コンテナが起動する

### Step 2: Playwright CLI のインストール

```bash
docker compose up -d playwright
docker compose exec playwright npm install -g @playwright/cli@latest
```

### Step 3: 動作確認

```bash
# バージョン確認
docker compose exec playwright playwright-cli --version

# アプリへのアクセス確認
docker compose exec playwright playwright-cli open http://app:8080 --headless
docker compose exec playwright playwright-cli snapshot
docker compose exec playwright playwright-cli close
```

### Step 4: スクリーンショット保存先の作成

```bash
mkdir -p tmp/webtest/screenshots
```

`tmp/webtest/` を `.gitignore` に追加する（まだの場合）:
```
tmp/webtest/
```

## Chrome DevTools MCP の設定（オプション）

Chrome DevTools MCP を使用する場合、CDP ポートを公開する。

### docker-compose.yaml の修正

```yaml
  playwright:
    image: mcr.microsoft.com/playwright:v1.50.0-noble
    working_dir: /work
    volumes:
      - .:/work
    depends_on:
      - app
    command: ["tail", "-f", "/dev/null"]
    ports:
      - "9222:9222"   # Chrome DevTools Protocol
    environment:
      - PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
```

### .mcp.json への追加

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--browserUrl", "http://localhost:9222"]
    }
  }
}
```

**注意**: Chrome DevTools MCP の接続は Playwright CLI で開いたブラウザインスタンスとの共存に制約がある場合がある。動作しない場合は Playwright CLI 単体で運用する。

## カスタム Dockerfile（オプション）

`@playwright/cli` を毎回インストールする手間を省くため、カスタムイメージを作成する案。

```dockerfile
# Dockerfile.playwright
FROM mcr.microsoft.com/playwright:v1.50.0-noble

RUN npm install -g @playwright/cli@latest

WORKDIR /work
CMD ["tail", "-f", "/dev/null"]
```

```yaml
# docker-compose.yaml
  playwright:
    build:
      context: .
      dockerfile: Dockerfile.playwright
    working_dir: /work
    volumes:
      - .:/work
    depends_on:
      - app
```

## トラブルシューティング

### `playwright-cli` が見つからない

```bash
# Node.js のグローバルパスを確認
docker compose exec playwright npm root -g

# 直接パスで実行
docker compose exec playwright npx @playwright/cli --version
```

### アプリに接続できない

```bash
# コンテナ間のネットワークを確認
docker compose exec playwright ping app

# アプリのポートを確認
docker compose exec playwright curl -s http://app:8080/health
```

### スクリーンショットが保存されない

```bash
# 保存先ディレクトリの権限を確認
docker compose exec playwright ls -la /work/tmp/webtest/screenshots/

# 手動でディレクトリ作成
docker compose exec playwright mkdir -p /work/tmp/webtest/screenshots
```

### `@playwright/cli` が存在しない場合のフォールバック

`@playwright/cli` が npm で利用できない場合（パッケージが新しいため）:

1. `@playwright/mcp` を MCP サーバーとして設定する
2. docker-compose.yaml を修正:
   ```yaml
   playwright:
     image: mcr.microsoft.com/playwright:v1.50.0-noble
     working_dir: /work
     volumes:
       - .:/work
     depends_on:
       - app
     command: ["npx", "@playwright/mcp@latest", "--headless", "--port", "8931", "--host", "0.0.0.0"]
     ports:
       - "8931:8931"
   ```
3. `.mcp.json` に追加:
   ```json
   {
     "mcpServers": {
       "playwright": {
         "type": "sse",
         "url": "http://localhost:8931/sse"
       }
     }
   }
   ```

## ローカル MCP セットアップ

Docker を使わずにローカル環境で `@playwright/mcp` を直接実行する方法。

### 前提

- Node.js v18 以上がインストールされていること

### Step 1: `.mcp.json` に Playwright MCP を設定

プロジェクトルートの `.mcp.json` に以下を追加する:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--headless"]
    }
  }
}
```

### Step 2: スクリーンショット保存先の作成

```bash
mkdir -p tmp/webtest/screenshots
```

`tmp/webtest/` を `.gitignore` に追加する（まだの場合）:
```
tmp/webtest/
```

### Step 3: テスト対象 URL

ローカル MCP モードでは Docker ネットワーク内のホスト名（`http://app:<port>`）は使えない。テスト対象 URL には `http://localhost:<port>` を使用する。

### トラブルシューティング

#### npx で `@playwright/mcp` が実行できない

```bash
# npx のキャッシュをクリアして再実行
npx --yes @playwright/mcp@latest --headless --help

# グローバルインストールで試す
npm install -g @playwright/mcp@latest
```

#### ブラウザが見つからない

`@playwright/mcp` は初回実行時にブラウザを自動ダウンロードする。手動でインストールする場合:

```bash
npx playwright install chromium
```
