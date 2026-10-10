# 技術スタック推奨表

dev-init スキルがヒアリング結果に基づいて技術スタックを推奨する際のロジックとデフォルト値を定義する。

## フレームワーク推奨マトリクス

### TypeScript

| プロジェクトタイプ | 推奨1 | 推奨2 | 推奨3 | 推奨4 |
|------------------|-------|-------|-------|-------|
| Webアプリ（フルスタック） | Next.js（App Router） | Remix | Hono + htmx | Astro |
| 3層Web（フロント） | Next.js（App Router） | Remix | Vite + React | Astro |
| 3層Web（バックエンド） | Hono | Fastify | Express | NestJS |
| BFF（UI） | Next.js（App Router） | Remix | Vite + React | — |
| BFF（モバイルUI） | React Native | Expo | — | — |
| BFF（BFF層） | Hono | Fastify | Express | NestJS |
| BFF（サービス層） | Hono | Fastify | NestJS | — |
| APIサーバー | Hono | Fastify | Express | NestJS |
| バッチ処理（cron/OS） | tsx（スクリプト実行） | node-cron | — | — |
| バッチ処理（クラウド） | tsx（スクリプト実行） | Hono（Webhook受信） | — | — |
| バッチ処理（FW内蔵） | BullMQ | node-cron | Agenda | — |
| マイクロサービス（REST） | Hono | Fastify | NestJS | — |
| マイクロサービス（gRPC） | NestJS | grpc-js + Fastify | Hono + nice-grpc | — |
| マイクロサービス（メッセージキュー） | （イベント駆動の該当ブローカー行を参照） | — | — | — |
| イベント駆動（Kafka） | Hono + KafkaJS | Fastify + KafkaJS | — | — |
| イベント駆動（RabbitMQ） | Hono + amqplib | Fastify + amqplib | — | — |
| イベント駆動（SQS/SNS） | Hono + @aws-sdk | Fastify + @aws-sdk | — | — |
| イベント駆動（Redis） | Hono + ioredis | Fastify + ioredis | — | — |
| GAS | clasp + esbuild | clasp + rollup | — | — |
| CLIツール | Commander.js | oclif | — | — |
| ライブラリ/パッケージ | （FW不要） | — | — | — |

### Python

| プロジェクトタイプ | 推奨1 | 推奨2 | 推奨3 |
|------------------|-------|-------|-------|
| Webアプリ（フルスタック） | Django | FastAPI + Jinja2 | Flask |
| 3層Web（バックエンド） | FastAPI | Django REST Framework | Flask |
| BFF（BFF層） | FastAPI | Flask | Litestar |
| BFF（サービス層） | FastAPI | Django REST Framework | Flask |
| APIサーバー | FastAPI | Django REST Framework | Flask |
| バッチ処理（cron/OS） | スクリプト実行 | APScheduler | — |
| バッチ処理（クラウド） | FastAPI（Webhook受信） | Flask | — |
| バッチ処理（FW内蔵） | Celery | APScheduler | Dramatiq |
| マイクロサービス（REST） | FastAPI | Flask | Litestar |
| マイクロサービス（gRPC） | grpcio + FastAPI | grpcio | — |
| マイクロサービス（メッセージキュー） | （イベント駆動の該当ブローカー行を参照） | — | — |
| イベント駆動（Kafka） | FastAPI + aiokafka | Faust | — |
| イベント駆動（RabbitMQ） | FastAPI + aio-pika | Celery | — |
| イベント駆動（SQS/SNS） | FastAPI + boto3 | — | — |
| イベント駆動（Redis） | FastAPI + redis-py | — | — |
| CLIツール | Typer | Click | argparse |
| ライブラリ/パッケージ | （FW不要） | — | — |

### Rust

| プロジェクトタイプ | 推奨1 | 推奨2 | 推奨3 |
|------------------|-------|-------|-------|
| Webアプリ（フルスタック） | Axum + Leptos | Actix Web | — |
| 3層Web（バックエンド） | Axum | Actix Web | Rocket |
| BFF（BFF層） | Axum | Actix Web | Rocket |
| BFF（サービス層） | Axum | Actix Web | Rocket |
| APIサーバー | Axum | Actix Web | Rocket |
| バッチ処理（cron/OS） | tokio（スクリプト実行） | clap + tokio | — |
| バッチ処理（クラウド） | Axum（Webhook受信） | clap + tokio | — |
| バッチ処理（FW内蔵） | tokio-cron-scheduler | clap + tokio | — |
| マイクロサービス（REST） | Axum | Actix Web | Rocket |
| マイクロサービス（gRPC） | Tonic | Axum + tonic | — |
| マイクロサービス（メッセージキュー） | （イベント駆動の該当ブローカー行を参照） | — | — |
| イベント駆動（Kafka） | Axum + rdkafka | Actix Web + rdkafka | — |
| イベント駆動（RabbitMQ） | Axum + lapin | Actix Web + lapin | — |
| イベント駆動（SQS/SNS） | Axum + aws-sdk-rust | — | — |
| イベント駆動（Redis） | Axum + redis-rs | — | — |
| CLIツール | clap | — | — |
| ライブラリ/パッケージ | （FW不要） | — | — |

### Go

| プロジェクトタイプ | 推奨1 | 推奨2 | 推奨3 |
|------------------|-------|-------|-------|
| Webアプリ（フルスタック） | Echo + templ | Gin | Chi |
| 3層Web（バックエンド） | Echo | Gin | Chi |
| BFF（BFF層） | Echo | Gin | Chi |
| BFF（サービス層） | Echo | Gin | Chi |
| APIサーバー | Echo | Gin | Chi |
| バッチ処理（cron/OS） | cobra + cron | スクリプト実行 | — |
| バッチ処理（クラウド） | Echo（Webhook受信） | cobra | — |
| バッチ処理（FW内蔵） | go-co-op/gocron | robfig/cron | — |
| マイクロサービス（REST） | Echo | Gin | Chi |
| マイクロサービス（gRPC） | grpc-go | go-micro | — |
| マイクロサービス（メッセージキュー） | （イベント駆動の該当ブローカー行を参照） | — | — |
| イベント駆動（Kafka） | Echo + sarama | Gin + sarama | — |
| イベント駆動（RabbitMQ） | Echo + amqp091-go | Gin + amqp091-go | — |
| イベント駆動（SQS/SNS） | Echo + aws-sdk-go-v2 | Gin + aws-sdk-go-v2 | — |
| イベント駆動（Redis） | Echo + go-redis | Gin + go-redis | — |
| CLIツール | cobra | urfave/cli | — |
| ライブラリ/パッケージ | （FW不要） | — | — |

### Java

| プロジェクトタイプ | 推奨1 | 推奨2 | 推奨3 | 推奨4 |
|------------------|-------|-------|-------|-------|
| Webアプリ（フルスタック） | Spring Boot | Quarkus | Micronaut | — |
| 3層Web（バックエンド） | Spring Boot | Quarkus | Micronaut | — |
| BFF（BFF層） | Spring Boot | Quarkus | Micronaut | — |
| BFF（サービス層） | Spring Boot | Quarkus | Micronaut | — |
| APIサーバー | Spring Boot | Quarkus | Micronaut | — |
| バッチ処理（cron/OS） | Spring Batch | Quarkus | — | — |
| バッチ処理（クラウド） | Spring Boot（Webhook受信） | Quarkus | — | — |
| バッチ処理（FW内蔵） | Spring Batch + Spring Scheduler | Quarkus Scheduler | — | — |
| マイクロサービス（REST） | Spring Boot | Quarkus | Micronaut | — |
| マイクロサービス（gRPC） | Spring Boot + grpc-spring-boot-starter | Quarkus gRPC | Micronaut gRPC | — |
| マイクロサービス（メッセージキュー） | （イベント駆動の該当ブローカー行を参照） | — | — | — |
| イベント駆動（Kafka） | Spring Boot + Spring Kafka | Quarkus + SmallRye Reactive | — | — |
| イベント駆動（RabbitMQ） | Spring Boot + Spring AMQP | Quarkus + SmallRye Reactive | — | — |
| イベント駆動（SQS/SNS） | Spring Boot + Spring Cloud AWS | — | — | — |
| イベント駆動（Redis） | Spring Boot + Spring Data Redis | — | — | — |
| CLIツール | picocli | Spring Shell | — | — |
| ライブラリ/パッケージ | （FW不要） | — | — | — |

### Kotlin

| プロジェクトタイプ | 推奨1 | 推奨2 | 推奨3 |
|------------------|-------|-------|-------|
| Webアプリ（フルスタック） | Spring Boot (Kotlin) | Ktor | — |
| 3層Web（バックエンド） | Ktor | Spring Boot (Kotlin) | — |
| BFF（BFF層） | Ktor | Spring Boot (Kotlin) | — |
| BFF（サービス層） | Ktor | Spring Boot (Kotlin) | — |
| APIサーバー | Ktor | Spring Boot (Kotlin) | — |
| バッチ処理（cron/OS） | Spring Batch (Kotlin) | Ktor | — |
| バッチ処理（クラウド） | Ktor（Webhook受信） | Spring Boot (Kotlin) | — |
| バッチ処理（FW内蔵） | Spring Batch (Kotlin) + Spring Scheduler | Quarkus Scheduler | — |
| マイクロサービス（REST） | Ktor | Spring Boot (Kotlin) | — |
| マイクロサービス（gRPC） | grpc-kotlin + Ktor | Spring Boot (Kotlin) + grpc-spring-boot-starter | — |
| マイクロサービス（メッセージキュー） | （イベント駆動の該当ブローカー行を参照） | — | — |
| イベント駆動（Kafka） | Ktor + kotlin-kafka | Spring Boot (Kotlin) + Spring Kafka | — |
| イベント駆動（RabbitMQ） | Ktor + rabbitmq-kotlin | Spring Boot (Kotlin) + Spring AMQP | — |
| イベント駆動（SQS/SNS） | Ktor + aws-sdk-kotlin | Spring Boot (Kotlin) + Spring Cloud AWS | — |
| イベント駆動（Redis） | Ktor + kreds | Spring Boot (Kotlin) + Spring Data Redis | — |
| CLIツール | clikt | picocli | — |
| ライブラリ/パッケージ | （FW不要） | — | — |

### Dart

| プロジェクトタイプ | 推奨1 | 推奨2 | 推奨3 |
|------------------|-------|-------|-------|
| Webアプリ（モバイル含む） | Flutter | — | — |
| BFF（UI） | Flutter | — | — |
| APIサーバー | dart_frog | shelf | — |
| CLIツール | dcli | args | — |
| ライブラリ/パッケージ | （FW不要） | — | — |

## パッケージマネージャ推奨表

| 言語 | 推奨（デフォルト） | 代替 | 備考 |
|------|------------------|------|------|
| TypeScript | pnpm | bun, yarn, npm | pnpm: ディスク効率・厳格な依存管理 |
| Python | uv | pip, poetry, rye | uv: 高速・Rust製 |
| Rust | cargo | — | 標準 |
| Go | go mod | — | 標準 |
| Java | Gradle (Kotlin DSL) | Maven | — |
| Kotlin | Gradle (Kotlin DSL) | — | — |
| Dart | pub | — | Flutter プロジェクトでも pub を使用 |

## テストフレームワーク推奨表

| 言語 | 単体テスト（推奨） | E2Eテスト | カバレッジ |
|------|------------------|----------|-----------|
| TypeScript | Vitest | Playwright | vitest --coverage |
| Python | pytest | Playwright | pytest --cov |
| Rust | cargo test（標準） | — | cargo tarpaulin |
| Go | go test + testify | — | go test -cover |
| Java | JUnit 5 | — | JaCoCo |
| Kotlin | JUnit 5 + kotlin-test | — | Kover |
| Dart | package:test | integration_test | dart test --coverage |

## Linter / Formatter 推奨表

| 言語 | Linter + Formatter（推奨） | 代替 |
|------|--------------------------|------|
| TypeScript | Biome | ESLint + Prettier |
| Python | Ruff | flake8 + black |
| Rust | clippy + rustfmt | — |
| Go | golangci-lint + gofmt | — |
| Java | Checkstyle + google-java-format | — |
| Kotlin | ktlint + detekt | — |
| Dart | dart analyze + dart format | — |

## データベース推奨ロジック

| 条件 | 推奨 | 理由 |
|------|------|------|
| 汎用・デフォルト | PostgreSQL | 拡張性・エコシステム・信頼性 |
| 組み込み・軽量・開発用 | SQLite | ゼロ設定・ファイルベース |
| ドキュメント指向・スキーマレス | MongoDB | 柔軟なスキーマ |
| KV・キャッシュ | Redis | 高速・インメモリ |

## ディレクトリ構造テンプレート

> `project-root/` = `$(git rev-parse --show-toplevel)` で取得するプロジェクトルートディレクトリ

### TypeScript Webアプリ（Next.js）

```
project-root/
├── src/
│   ├── app/              # App Router pages & layouts
│   ├── components/       # UIコンポーネント
│   ├── lib/              # ビジネスロジック・ユーティリティ
│   └── types/            # 型定義
├── tests/
│   ├── unit/             # 単体テスト
│   └── e2e/              # E2Eテスト
├── public/               # 静的ファイル
├── package.json
├── tsconfig.json
├── biome.json
└── vitest.config.ts
```

### TypeScript APIサーバー（Hono）

```
project-root/
├── src/
│   ├── routes/           # ルートハンドラ
│   ├── services/         # ビジネスロジック
│   ├── repositories/     # データアクセス
│   ├── middleware/        # ミドルウェア
│   ├── types/            # 型定義
│   └── index.ts          # エントリポイント
├── tests/
│   ├── unit/
│   └── integration/
├── package.json
├── tsconfig.json
├── biome.json
└── vitest.config.ts
```

### Python APIサーバー（FastAPI）

```
project-root/
├── src/
│   └── app/
│       ├── routers/      # ルーター
│       ├── services/     # ビジネスロジック
│       ├── repositories/ # データアクセス
│       ├── models/       # データモデル
│       ├── schemas/      # Pydanticスキーマ
│       └── main.py       # エントリポイント
├── tests/
│   ├── unit/
│   └── integration/
├── pyproject.toml
└── ruff.toml
```

### Rust CLIツール

```
project-root/
├── src/
│   ├── commands/         # サブコマンド
│   ├── config/           # 設定
│   ├── lib.rs            # ライブラリルート
│   └── main.rs           # エントリポイント
├── tests/
│   └── integration/
├── Cargo.toml
└── clippy.toml
```

### Go APIサーバー

```
project-root/
├── cmd/
│   └── server/
│       └── main.go       # エントリポイント
├── internal/
│   ├── handler/          # HTTPハンドラ
│   ├── service/          # ビジネスロジック
│   ├── repository/       # データアクセス
│   └── model/            # データモデル
├── pkg/                  # 外部公開パッケージ
├── go.mod
└── go.sum
```

### Java APIサーバー（Spring Boot）

```
project-root/
├── src/
│   ├── main/
│   │   ├── java/com/example/app/
│   │   │   ├── controller/    # RESTコントローラ
│   │   │   ├── service/       # ビジネスロジック
│   │   │   ├── repository/    # データアクセス
│   │   │   ├── model/         # エンティティ
│   │   │   ├── dto/           # データ転送オブジェクト
│   │   │   └── Application.java
│   │   └── resources/
│   │       └── application.yml
│   └── test/java/com/example/app/
├── build.gradle.kts
└── settings.gradle.kts
```

### Kotlin APIサーバー（Ktor）

```
project-root/
├── src/
│   ├── main/kotlin/com/example/app/
│   │   ├── plugins/           # Ktor プラグイン設定
│   │   ├── routes/            # ルーティング
│   │   ├── service/           # ビジネスロジック
│   │   ├── repository/        # データアクセス
│   │   ├── model/             # データモデル
│   │   └── Application.kt
│   └── test/kotlin/com/example/app/
├── build.gradle.kts
└── settings.gradle.kts
```

### Dart Webアプリ（Flutter）

```
project-root/
├── lib/
│   ├── src/
│   │   ├── features/          # 機能別モジュール
│   │   ├── core/              # 共通ロジック
│   │   └── widgets/           # 共通ウィジェット
│   └── main.dart              # エントリポイント
├── test/
│   ├── unit/
│   └── widget/
├── integration_test/
├── pubspec.yaml
└── analysis_options.yaml
```

### 3層Webアプリ（モノレポ）

```
project-root/
├── packages/
│   ├── frontend/            # TypeScript フロントエンド
│   │   ├── src/
│   │   │   ├── app/         # App Router pages & layouts
│   │   │   ├── components/  # UIコンポーネント
│   │   │   └── lib/         # フロント用ユーティリティ
│   │   ├── CLAUDE.md        # フロントエンド固有の指示
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── backend/             # Q2言語 バックエンド
│   │   ├── src/
│   │   │   ├── routes/      # ルートハンドラ
│   │   │   ├── services/    # ビジネスロジック
│   │   │   └── repositories/ # データアクセス
│   │   ├── CLAUDE.md        # バックエンド固有の指示
│   │   └── package.json     # or Cargo.toml / go.mod 等
│   └── shared/              # 共有型定義・ユーティリティ
│       ├── src/
│       │   └── types/
│       └── package.json
├── tests/
│   ├── unit/
│   └── e2e/
├── CLAUDE.md                # ワークスペース共通の指示
├── package.json             # ワークスペースルート
├── pnpm-workspace.yaml
└── biome.json
```

### BFF（Webのみ・単一サービス・モノレポ）

```
project-root/
├── packages/
│   ├── web-ui/              # Q4a言語 フロントエンド
│   │   ├── src/
│   │   │   ├── app/
│   │   │   └── components/
│   │   ├── CLAUDE.md        # UI固有の指示
│   │   └── package.json
│   ├── bff/                 # Q4b言語 BFF層
│   │   ├── src/
│   │   │   ├── routes/      # API集約ルート
│   │   │   ├── aggregators/ # データ集約・整形
│   │   │   └── middleware/
│   │   ├── CLAUDE.md        # BFF固有の指示
│   │   └── package.json
│   ├── service/             # Q4c言語 サービス層
│   │   ├── src/
│   │   │   ├── routes/
│   │   │   ├── services/    # ビジネスロジック
│   │   │   └── repositories/
│   │   ├── CLAUDE.md        # サービス固有の指示
│   │   └── package.json
│   └── shared/              # 共有型定義（同一言語: TS型、混合言語: OpenAPI/protobuf）
│       └── package.json
├── CLAUDE.md                # ワークスペース共通の指示
├── package.json
├── pnpm-workspace.yaml      # 全層TS時。混合言語時は Makefile + Docker Compose ベース
└── biome.json
```

### BFF（モバイルのみ・単一サービス・モノレポ）

```
project-root/
├── packages/
│   ├── mobile-ui/           # Q4a言語 モバイルUI（Docker外で実行）
│   │   ├── lib/             # or src/（言語依存）
│   │   ├── CLAUDE.md        # モバイルUI固有の指示
│   │   └── pubspec.yaml     # or package.json（言語依存）
│   ├── bff/                 # Q4b言語 BFF層
│   │   ├── src/
│   │   │   ├── routes/
│   │   │   ├── aggregators/
│   │   │   └── middleware/
│   │   ├── CLAUDE.md        # BFF固有の指示
│   │   └── package.json
│   ├── service/             # Q4c言語 サービス層
│   │   ├── src/
│   │   │   ├── routes/
│   │   │   ├── services/
│   │   │   └── repositories/
│   │   ├── CLAUDE.md        # サービス固有の指示
│   │   └── package.json
│   └── shared/              # 共有型定義（OpenAPI/protobuf 推奨）
│       └── package.json
├── CLAUDE.md                # ワークスペース共通の指示
├── package.json
└── Makefile                 # 混合言語ビルドオーケストレーション
```

### BFF（Web+モバイル・単一サービス・モノレポ）

```
project-root/
├── packages/
│   ├── web-ui/              # TypeScript フロントエンド
│   │   ├── src/
│   │   │   ├── app/
│   │   │   └── components/
│   │   ├── CLAUDE.md        # WebUI固有の指示
│   │   └── package.json
│   ├── mobile-ui/           # Q4a言語 モバイルUI（Docker外で実行）
│   │   ├── lib/
│   │   ├── CLAUDE.md        # モバイルUI固有の指示
│   │   └── pubspec.yaml
│   ├── bff/                 # Q4b言語 BFF層
│   │   ├── src/
│   │   │   ├── routes/
│   │   │   ├── aggregators/
│   │   │   └── middleware/
│   │   ├── CLAUDE.md        # BFF固有の指示
│   │   └── package.json
│   ├── service/             # Q4c言語 サービス層
│   │   ├── src/
│   │   │   ├── routes/
│   │   │   ├── services/
│   │   │   └── repositories/
│   │   ├── CLAUDE.md        # サービス固有の指示
│   │   └── package.json
│   └── shared/              # 共有型定義（OpenAPI/protobuf 推奨）
│       └── package.json
├── CLAUDE.md                # ワークスペース共通の指示
├── package.json
└── Makefile                 # 混合言語ビルドオーケストレーション
```

### BFF（複数サービス・モノレポ）

```
project-root/
├── packages/
│   ├── web-ui/              # Q4a言語 フロントエンド
│   │   ├── CLAUDE.md        # UI固有の指示
│   │   └── ...
│   ├── bff/                 # Q4b言語 BFF層
│   │   ├── CLAUDE.md        # BFF固有の指示
│   │   └── ...
│   └── shared/              # 共有型定義
│       └── ...
├── services/
│   ├── service-a/           # サービスA
│   │   ├── src/
│   │   ├── CLAUDE.md        # サービスA固有の指示
│   │   └── package.json
│   └── service-b/           # サービスB
│       ├── src/
│       ├── CLAUDE.md        # サービスB固有の指示
│       └── package.json
├── CLAUDE.md                # ワークスペース共通の指示
├── package.json
├── pnpm-workspace.yaml      # 全層TS時。混合言語時は Makefile + Docker Compose ベース
└── biome.json
```

### バッチ処理

```
project-root/
├── src/
│   ├── jobs/                # ジョブ定義
│   ├── processors/          # 処理ロジック
│   ├── config/              # 設定・スケジュール定義
│   ├── utils/               # ユーティリティ
│   └── index.ts             # エントリポイント
├── tests/
│   ├── unit/
│   └── integration/
├── package.json
└── biome.json
```

### マイクロサービス（モノレポ）

```
project-root/
├── services/
│   ├── service-a/
│   │   ├── src/
│   │   │   ├── routes/
│   │   │   ├── services/
│   │   │   └── index.ts
│   │   ├── tests/
│   │   ├── CLAUDE.md        # サービスA固有の指示
│   │   ├── Dockerfile
│   │   └── package.json
│   └── service-b/
│       ├── src/
│       ├── tests/
│       ├── CLAUDE.md        # サービスB固有の指示
│       ├── Dockerfile
│       └── package.json
├── packages/
│   └── shared/              # 共有型定義・プロトコル定義
│       └── package.json
├── CLAUDE.md                # ワークスペース共通の指示
├── package.json
├── pnpm-workspace.yaml
└── biome.json
```

### イベント駆動

```
project-root/
├── src/
│   ├── events/              # イベントスキーマ定義
│   ├── producers/           # イベント発行
│   ├── consumers/           # イベント消費
│   ├── services/            # ビジネスロジック
│   ├── config/              # ブローカー接続設定
│   └── index.ts             # エントリポイント
├── tests/
│   ├── unit/
│   └── integration/
├── package.json
└── biome.json
```

### GAS（スタンドアロン）

```
project-root/
├── src/
│   ├── main.ts              # エントリポイント
│   ├── functions/           # メイン機能
│   ├── triggers/            # トリガー定義
│   └── utils/               # ユーティリティ
├── tests/
│   └── unit/
├── dist/                    # ビルド成果物（.gitignore対象）
├── .clasp.json              # clasp プロジェクト設定
├── appsscript.json          # GAS マニフェスト
├── package.json
├── tsconfig.json
├── biome.json
└── vitest.config.ts
```

### GAS（スプレッドシート連携）

```
project-root/
├── src/
│   ├── main.ts              # エントリポイント（onOpen メニュー登録）
│   ├── menu/                # カスタムメニュー定義
│   ├── functions/           # カスタム関数（CUSTOM_FUNC 等）
│   ├── sheets/              # シート操作ロジック
│   ├── triggers/            # トリガー定義
│   └── utils/               # ユーティリティ
├── tests/
│   └── unit/
├── dist/
├── .clasp.json
├── appsscript.json          # oauthScopes にスプレッドシート権限を含む
├── package.json
├── tsconfig.json
├── biome.json
└── vitest.config.ts
```

### GAS（Webアプリ）

```
project-root/
├── src/
│   ├── main.ts              # エントリポイント
│   ├── webapp/              # doGet/doPost ハンドラ
│   │   ├── router.ts        # リクエストルーティング
│   │   └── handlers/        # 各エンドポイントハンドラ
│   ├── templates/           # HTMLテンプレート
│   ├── functions/           # 共通機能
│   ├── triggers/            # トリガー定義
│   └── utils/               # ユーティリティ
├── tests/
│   └── unit/
├── dist/
├── .clasp.json
├── appsscript.json          # webapp セクション含む（executeAs, access）
├── package.json
├── tsconfig.json
├── biome.json
└── vitest.config.ts
```

## GAS 固有設定

| 項目 | 推奨 | 代替 |
|------|------|------|
| 言語 | TypeScript（固定） | — |
| デプロイツール | clasp | — |
| バンドラ | esbuild | rollup, webpack |
| 型定義 | @types/google-apps-script | — |
| テスト | Vitest | Jest |
| Linter/Formatter | Biome | ESLint + Prettier |
| パッケージマネージャ | pnpm | npm |

## チーム規模による調整

| 項目 | 個人・プロトタイプ | 小規模（2-5人） | 中〜大規模（6人+） |
|------|------------------|----------------|-------------------|
| 型安全性 | 緩め可 | 標準 | 厳格（strict mode） |
| Linter設定 | 最小 | 標準 | 厳格・カスタムルール |
| テスト | 主要パスのみ | 単体+結合 | 単体+結合+E2E |
| CI/CD | なし〜簡易 | GitHub Actions | 本格CI/CD |
| ドキュメント | 最小 | README + API docs | 包括的ドキュメント |
| コードレビュー | なし | 任意 | 必須 |

## Docker 開発環境

### 言語別ランタイムイメージ表

| 言語 | 開発用イメージ | デプロイ用イメージ | 備考 |
|------|-------------|----------------|------|
| TypeScript (Node) | `node:20-slim` | `node:20-slim`（マルチステージ） | Bun: `oven/bun:1` |
| Python | `python:3.12-slim` | `python:3.12-slim`（マルチステージ） | uv を COPY --from で追加 |
| Rust | `rust:1.82` | `debian:bookworm-slim` | 開発用は cargo-watch 必要 |
| Go | `golang:1.22` | `gcr.io/distroless/static-debian12` | 開発用は air 必要 |
| Java | `eclipse-temurin:21` | `eclipse-temurin:21-jre-jammy` | 開発時は JDK、本番は JRE |
| Kotlin | `eclipse-temurin:21` | `eclipse-temurin:21-jre-jammy` | Java と共通 |
| Dart | `dart:stable` | `scratch` / `gcr.io/distroless/cc` | AOT コンパイルで単一バイナリ |

### Hot-Reload ツール推奨表

| 言語 | ツール | インストール | コマンド |
|------|-------|------------|---------|
| TypeScript | tsx --watch | devDependencies に含む | `pnpm dev` |
| Python | uvicorn --reload | uvicorn に内蔵 | `uv run uvicorn --reload` |
| Rust | cargo-watch | `cargo install cargo-watch` | `cargo watch -x run` |
| Go | air | `go install github.com/air-verse/air@latest` | `air` |
| Java | Spring DevTools | dependencies に含む | `./gradlew bootRun` |
| Kotlin | Gradle continuous | Gradle に内蔵 | `./gradlew run --continuous` |
| Dart | VM service | Dart に内蔵 | `dart run --enable-vm-service` |

### Volume Mount パフォーマンス注意（macOS）

macOS の Docker Desktop では volume mount のパフォーマンスが Linux より低下する場合がある:

- **依存ディレクトリは named volume を使用**: `node_modules`, `target`, `.gradle` 等を named volume にマウントすることで I/O を高速化
- **VirtioFS を有効化**: Docker Desktop の設定で VirtioFS ファイル共有を選択（デフォルトで有効）
- **不要なファイルの除外**: `.dockerignore` でビルド成果物・ログを除外

## 推奨ロジックの優先順位

1. **ユーザーの明示的な選択** を最優先する
2. **チーム規模** に応じて堅牢性のレベルを調整する
3. **エコシステムの成熟度** を考慮する（枯れた技術 > 最新技術）
4. **dev-*スキルとの相性** を考慮する（テスト容易性が高いFWを優先）
5. 迷った場合は **「推奨」列の最初の選択肢** をデフォルトとする
