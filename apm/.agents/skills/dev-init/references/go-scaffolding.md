# Go スキャフォールディングガイド

## CLI ツール

| コマンド | 用途 |
|---------|------|
| `go mod init <module-path>` | go.mod 初期化（例: `github.com/user/project`） |
| `go mod tidy` | 依存の整理・不要依存の削除 |
| `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest` | Linter インストール |

Go は CLI スキャフォールドツールを持たない。ディレクトリ構造を手動で構築する。

## パッケージ定義

### 必須依存パッケージ

| タイプ | FW | dependencies |
|--------|-----|-------------|
| Web/API | Echo | `github.com/labstack/echo/v4` |
| Web/API | Gin | `github.com/gin-gonic/gin` |
| Web/API | Chi | `github.com/go-chi/chi/v5` |
| CLI | cobra | `github.com/spf13/cobra` |
| テスト補助 | testify | `github.com/stretchr/testify`（dev のみ） |

### go.mod 重要フィールド

- `go`: Go バージョン指定（`go 1.22`）
- `module`: モジュールパス

### ディレクトリ構造ガイド

Go はディレクトリ構造が特に重要（慣習ベース）。`project-root/` = `$(git rev-parse --show-toplevel)` で取得するプロジェクトルートディレクトリ。

```
project-root/
├── cmd/<app-name>/main.go    # エントリポイント
├── internal/                  # プライベートパッケージ（外部非公開）
│   ├── handler/              # HTTP ハンドラ
│   ├── service/              # ビジネスロジック
│   ├── repository/           # データアクセス
│   └── model/                # データモデル
├── pkg/                      # 外部公開パッケージ（ライブラリの場合）
├── go.mod
└── go.sum
```

CLI の場合:
```
project-root/
├── cmd/<app-name>/main.go
├── internal/
│   └── cmd/                  # サブコマンド定義
├── go.mod
└── go.sum
```

## 設定ファイル

### golangci-lint 設定（.golangci.yml）

```yaml
linters:
  enable:
    - errcheck
    - govet
    - staticcheck
    - unused
    - gosimple
    - ineffassign
```

チーム規模別:
- 個人: `go vet` のみ
- 小規模: 上記基本セット
- 大規模: `+ gocyclo, dupl, goconst, misspell, revive`

### テスト設定

Go はテスト設定ファイル不要。`*_test.go` を同パッケージに配置するだけ。

## エントリポイント

| タイプ | パス | 内容 |
|--------|------|------|
| API (Echo) | `cmd/server/main.go` | Echo インスタンス作成・ルート登録・Start |
| API (Gin) | `cmd/server/main.go` | Gin Engine 作成・ルート登録・Run |
| CLI (cobra) | `cmd/<name>/main.go` | rootCmd.Execute() |
| ライブラリ | `<package>.go` | パッケージルート |

## テスト雛形

- ファイル配置: 対象ファイルと同ディレクトリに `<name>_test.go`
- テーブルドリブンテスト推奨
- API テスト: `net/http/httptest` パッケージ
- 最小構成: ハンドラの HTTP テスト or パッケージのインポート確認

## Docker ガイド

- ベースイメージ: `golang:1.22` → 本番: `gcr.io/distroless/static-debian12`
- マルチステージ: `builder`（`CGO_ENABLED=0 go build`）→ `runner`（バイナリのみ）
- `.dockerignore`: `.git`, `.env*`, `*.test`

### 開発用 Docker

- 開発用ベースイメージ: `golang:1.22`
- Volume mount: `- .:/app` でソースコードをマウント、`go-mod-cache` は named volume で分離
- Hot-reload: `air`（air のインストールが必要）で自動再起動
- Linter: `golangci-lint`（Dockerfile.dev でインストール）
- Dockerfile.dev: マルチステージ不要、air + golangci-lint インストール + go mod download + air コマンド
- `.air.toml` を生成し、監視対象を制限する:
  - `root` = `"."`
  - `watch_dir` = `["cmd", "internal"]`（`pkg` がある場合は追加）
  - `exclude_dir` = `["tmp", "vendor", ".git", "node_modules"]`
  - `include_ext` = `["go", "toml", "yaml"]`

## CI (GitHub Actions) ガイド

- Go セットアップ: `actions/setup-go@v5` + `go-version-file: 'go.mod'`
- キャッシュ: `actions/setup-go` が自動キャッシュ
- Lint: `golangci/golangci-lint-action@v6`
- ステップ: lint → `go test ./...` → `go build ./...`

## 検証コマンド

| 操作 | コマンド |
|------|---------|
| 依存解決 | `go mod tidy` |
| ビルド | `go build ./...` |
| テスト | `go test ./...` |
| テスト（カバレッジ） | `go test -cover ./...` |
| Lint | `golangci-lint run` |
| フォーマット確認 | `gofmt -l .` |
| Vet | `go vet ./...` |
