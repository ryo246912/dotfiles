# TypeScript スキャフォールディングガイド

## CLI ツール

| FW | コマンド | 非対話フラグ |
|----|---------|-------------|
| Next.js | `npx create-next-app@latest <name>` | `--ts --app --src-dir --tailwind --eslint --import-alias "@/*" --use-pnpm` |
| Remix | `npx create-remix@latest <name>` | `--template remix-run/remix/templates/basic` |
| Hono | `npm create hono@latest <name>` | テンプレート選択が必要 → 直接生成推奨 |
| Astro | `npm create astro@latest <name>` | `--template minimal --install --no-git --typescript strict` |
| NestJS | `npx @nestjs/cli new <name>` | `--package-manager pnpm --strict` |
| oclif | `npx oclif generate <name>` | 対話式のみ → 直接生成推奨 |
| （汎用） | `npm init -y` | — |

ランタイム選択: Node.js（デフォルト）/ Deno / Bun。Bun の場合は `bunx` に置換。

## パッケージ定義

### 必須依存パッケージ

| タイプ | FW | dependencies | devDependencies |
|--------|-----|-------------|-----------------|
| Web (Next.js) | Next.js | `next react react-dom` | `typescript @types/react @types/node @biomejs/biome` |
| API | Hono | `hono` | `typescript @types/node tsx @biomejs/biome` |
| API | Fastify | `fastify` | `typescript @types/node tsx @biomejs/biome` |
| API | Express | `express` | `typescript @types/express @types/node tsx @biomejs/biome` |
| CLI | Commander | `commander` | `typescript @types/node tsx @biomejs/biome` |
| ライブラリ | — | — | `typescript @biomejs/biome` |

### package.json 重要フィールド

- `type`: `"module"`（ESM推奨）
- `engines`: Node.js バージョン指定（`">=20"`）
- `scripts`: `dev`, `build`, `test`, `lint`, `start`

## 設定ファイル

### tsconfig.json 主要項目

- `target`: `"ES2022"` 以上
- `module`: `"NodeNext"` / `"ESNext"`
- `moduleResolution`: `"NodeNext"` / `"Bundler"`
- `strict`: `true`
- `outDir`: `"./dist"`
- `rootDir`: `"./src"`
- `paths`: エイリアス設定（`"@/*": ["./src/*"]`）

### テスト設定（vitest.config.ts）

- `include`: `["tests/**/*.test.ts"]`
- `coverage.provider`: `"v8"`
- `coverage.reporter`: `["text", "json-summary"]`

### Linter/Formatter（biome.json）

- `formatter.indentStyle`: `"space"` / `"tab"`
- `linter.rules.recommended`: `true`
- チーム規模大: `linter.rules.nursery` を追加有効化

## エントリポイント

| タイプ | パス | 内容 |
|--------|------|------|
| Web (Next.js) | `src/app/page.tsx` | ルートページコンポーネント |
| Web (Next.js) | `src/app/layout.tsx` | ルートレイアウト |
| API (Hono) | `src/index.ts` | アプリ作成・ルート登録・サーバー起動 |
| API (Fastify) | `src/index.ts` | Fastify インスタンス・プラグイン登録 |
| CLI | `src/index.ts` | コマンド定義・parse実行 |
| ライブラリ | `src/index.ts` | パブリック API のエクスポート |

## テスト雛形

- ファイル配置: `tests/unit/<module>.test.ts`
- 最小構成: 1つのスモークテスト（インポート確認 or サーバー起動確認）
- API: `app.request()` で HTTP テスト（Hono）/ `inject()` で HTTP テスト（Fastify）

## Docker ガイド

- ベースイメージ: `node:20-slim`（Bun: `oven/bun:1`）
- マルチステージ: `builder`（依存+ビルド）→ `runner`（本番）
- `.dockerignore`: `node_modules`, `dist`, `.git`, `.env*`
- pnpm の場合: `corepack enable && corepack prepare pnpm@latest --activate`

### 開発用 Docker

- 開発用ベースイメージ: `node:20-slim`（Bun: `oven/bun:1`）
- Volume mount: `- .:/app` でソースコードをマウント、`node_modules` は named volume で分離
- Hot-reload: `pnpm dev`（tsx --watch）で自動再起動
- Dockerfile.dev: マルチステージ不要、依存インストール + dev server コマンド

## CI (GitHub Actions) ガイド

- Node.js セットアップ: `actions/setup-node@v4` + `node-version-file: '.node-version'`
- pnpm キャッシュ: `actions/setup-node` の `cache: 'pnpm'`
- ステップ: install → lint → test → build
- マトリクス: Node.js バージョン（20, 22）

## 検証コマンド

| 操作 | コマンド (pnpm) | コマンド (bun) |
|------|----------------|----------------|
| 依存インストール | `pnpm install` | `bun install` |
| ビルド | `pnpm run build` | `bun run build` |
| テスト | `pnpm test` | `bun test` |
| Lint | `pnpm run lint` | `bun run lint` |
| 開発サーバー | `pnpm dev` | `bun dev` |
