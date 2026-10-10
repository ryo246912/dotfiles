# Rust スキャフォールディングガイド

## CLI ツール

| コマンド | 用途 | オプション |
|---------|------|-----------|
| `cargo init <name>` | 既存ディレクトリに初期化 | `--lib`（ライブラリ）、デフォルトはバイナリ |
| `cargo new <name>` | 新規ディレクトリ作成 | `--lib`（ライブラリ） |

cargo がプロジェクト構造・ビルド・テスト・依存管理を統合的に担う。追加ツールは不要。

## パッケージ定義

### 必須依存パッケージ

| タイプ | FW | dependencies | dev-dependencies |
|--------|-----|-------------|-----------------|
| Web | Axum + Leptos | `axum leptos tokio` | — |
| API | Axum | `axum tokio serde serde_json` | — |
| API | Actix Web | `actix-web serde serde_json tokio` | — |
| CLI | clap | `clap` (features: `["derive"]`) | — |
| ライブラリ | — | — | — |

Rust は `[dev-dependencies]` に直接テスト用クレートを記載:
- `tokio` (features: `["test-util"]`)、API テスト用: `reqwest` or `axum::test`

### Cargo.toml 重要フィールド

- `edition`: `"2024"`
- `rust-version`: MSRV 指定（`"1.80"` 等）
- `[profile.release]`: `lto = true`, `strip = true`（バイナリサイズ最適化）

## 設定ファイル

### clippy 設定（clippy.toml / Cargo.toml）

- Cargo.toml 内: `[lints.clippy]` セクションで lint レベル制御
- 推奨: `pedantic = "warn"`（チーム規模大）
- 個人: デフォルト lint のみ

### rustfmt 設定（rustfmt.toml）

- `edition`: `"2024"`
- `max_width`: `100`
- `use_field_init_shorthand`: `true`

### チーム規模別調整

- 個人: clippy デフォルト、`#[deny(warnings)]` なし
- 小規模: `clippy::all` を warn
- 大規模: `clippy::pedantic` を warn + `#![deny(missing_docs)]`

## エントリポイント

| タイプ | パス | 内容 |
|--------|------|------|
| API (Axum) | `src/main.rs` | Router 構築・`tokio::main` でサーバー起動 |
| API (Actix) | `src/main.rs` | `HttpServer::new` + `actix_web::main` |
| CLI (clap) | `src/main.rs` | `#[derive(Parser)]` 構造体 + `main()` |
| ライブラリ | `src/lib.rs` | パブリック API モジュール宣言 |

## テスト雛形

- 単体テスト: 同ファイル内 `#[cfg(test)] mod tests`
- 結合テスト: `tests/` ディレクトリ
- API テスト: `axum::test::TestClient` or `actix_web::test`
- 最小構成: `#[test] fn it_works()` + API の場合ヘルスチェックテスト

## Docker ガイド

- ベースイメージ: `rust:1.80-slim` → 本番: `debian:bookworm-slim`
- マルチステージ: `builder`（cargo build --release）→ `runner`（バイナリのみコピー）
- cargo キャッシュ最適化: `Cargo.toml` と `Cargo.lock` を先にコピーし `cargo build` でキャッシュ層作成
- `.dockerignore`: `target`, `.git`, `.env*`

### 開発用 Docker

- 開発用ベースイメージ: `rust:1.82`
- Volume mount: `- .:/app` でソースコードをマウント、`target` と `cargo-cache` は named volume で分離
- Hot-reload: `cargo watch -w src -w Cargo.toml -x run`（cargo-watch のインストールが必要）で自動再起動。`-w` で監視対象を `src/` と `Cargo.toml` に限定し、不要な再ビルドを防ぐ
- Dockerfile.dev: マルチステージ不要、cargo-watch インストール + 依存プリフェッチ + watch コマンド

## CI (GitHub Actions) ガイド

- Rust セットアップ: `dtolnay/rust-toolchain@stable`
- キャッシュ: `Swatinem/rust-cache@v2`
- ステップ: `cargo fmt --check` → `cargo clippy -- -D warnings` → `cargo test` → `cargo build --release`
- マトリクス: stable + MSRV

## 検証コマンド

| 操作 | コマンド |
|------|---------|
| 依存解決 | `cargo fetch` |
| ビルド | `cargo build` |
| テスト | `cargo test` |
| Lint | `cargo clippy -- -D warnings` |
| フォーマット確認 | `cargo fmt --check` |
| リリースビルド | `cargo build --release` |
