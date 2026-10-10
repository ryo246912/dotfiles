# デフォルト技術スタック定義

プロジェクト専用の技術スタック定義ファイルが見つからない場合に使用されるデフォルト定義です。

## 優先順位

1. **プロジェクト専用**: `docs/tech-stack.md`
2. **プロジェクト共通**: `CLAUDE.md` の技術スタックセクション  
3. **デフォルト**: この定義ファイル

## デフォルト技術スタック

### フロントエンド
- **フレームワーク**: React 18+ または Vue 3+ または Next.js
- **言語**: TypeScript 5.0+
- **状態管理**: Redux Toolkit または Zustand または Pinia
- **UIライブラリ**: Material-UI または Tailwind CSS または shadcn/ui
- **バンドラー**: Vite または Webpack

### バックエンド
- **フレームワーク**: Express.js または Fastify または Next.js API Routes
- **言語**: TypeScript 5.0+ または JavaScript ES2022+
- **データベース**: PostgreSQL 15+ または MySQL 8+ または SQLite
- **ORM**: Prisma または TypeORM または Drizzle
- **認証**: JWT または NextAuth.js

### キャッシュ・セッション
- **キャッシュ**: Redis 7+ または Memcached
- **セッション**: Redis または MemoryStore

### 開発環境
- **コンテナ**: Docker + Docker Compose
- **パッケージマネージャー**: npm または yarn または pnpm
- **Node.js**: 18+ LTS

### 開発ツール
- **テストフレームワーク**: Jest または Vitest
- **テストライブラリ**: Testing Library または Playwright
- **リンター**: ESLint + Prettier
- **型チェック**: TypeScript
- **CI/CD**: GitHub Actions または GitLab CI

### デプロイ・インフラ
- **フロントエンド**: Vercel または Netlify または Cloudflare Pages
- **バックエンド**: Railway または Heroku または AWS または GCP
- **データベース**: PostgreSQL (管理型) または自己管理
- **CDN**: Cloudflare または AWS CloudFront

## API設計
- **アーキテクチャ**: RESTful API または GraphQL
- **ドキュメント**: OpenAPI/Swagger または GraphQL Schema
- **認証方式**: Bearer Token (JWT) または API Key

## データ管理
- **データベース設計**: 正規化 + 必要に応じて非正規化
- **マイグレーション**: Prisma Migrate または TypeORM Migrations
- **バックアップ**: 自動バックアップ推奨

## セキュリティ
- **HTTPS**: 必須
- **CORS**: 適切な設定
- **認証**: JWT + Refresh Token パターン
- **バリデーション**: サーバーサイドバリデーション必須
- **環境変数**: 機密情報の適切な管理

## パフォーマンス要件
- **API応答時間**: 3秒以内
- **フロントエンド初期表示**: 2秒以内
- **データベースクエリ**: インデックス最適化
- **キャッシュ戦略**: 適切なTTL設定

## 品質基準
- **テストカバレッジ**: 80%以上推奨
- **コード品質**: ESLint + Prettier
- **型安全性**: TypeScript strict mode
- **アクセシビリティ**: WCAG 2.1 AA準拠推奨

## ディレクトリ構造（推奨）

```
project/
├── docs/                    # ドキュメント
│   ├── spec/               # 要件定義
│   ├── design/             # 設計文書
│   └── tasks/              # タスク管理
├── src/                    # ソースコード
│   ├── components/         # UIコンポーネント
│   ├── services/           # ビジネスロジック
│   ├── types/              # 型定義
│   └── utils/              # ユーティリティ
├── tests/                  # テストファイル
├── prisma/                 # データベーススキーマ
├── docker-compose.yml      # 開発環境
└── package.json           # 依存関係
```

## 使用方法

このデフォルト定義は以下の場合に参照されます：

1. `docs/tech-stack.md` が存在しない
2. `CLAUDE.md` に技術スタック情報がない
3. 新規プロジェクトの初期設定

プロジェクト固有の技術選択がある場合は、`docs/tech-stack.md` を作成して上書きしてください。