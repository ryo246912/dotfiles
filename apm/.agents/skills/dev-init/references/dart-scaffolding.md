# Dart (Flutter) スキャフォールディングガイド

## CLI ツール

| 用途 | コマンド | オプション |
|------|---------|-----------|
| Flutter アプリ | `flutter create <name>` | `--org <com.example> --platforms web,ios,android` |
| Flutter パッケージ | `flutter create --template=package <name>` | — |
| Flutter プラグイン | `flutter create --template=plugin <name>` | `--platforms` |
| Pure Dart パッケージ | `dart create -t package <name>` | — |
| Pure Dart CLI | `dart create -t console <name>` | — |
| dart_frog API | `dart_frog create <name>` | `dart pub global activate dart_frog_cli` が必要 |

### Flutter vs Pure Dart の分岐

- UI あり（モバイル/Web/デスクトップ）→ `flutter create`
- API サーバー → `dart create` + dart_frog / shelf
- CLI → `dart create -t console`
- ライブラリ（Flutter 依存あり）→ `flutter create --template=package`
- ライブラリ（Pure Dart）→ `dart create -t package`

## パッケージ定義

### 必須依存パッケージ

| タイプ | FW | dependencies | dev_dependencies |
|--------|-----|-------------|-----------------|
| モバイル/Web | Flutter | `flutter(sdk)` | `flutter_test(sdk) flutter_lints` |
| API | dart_frog | `dart_frog` | `test dart_frog_test mocktail` |
| API | shelf | `shelf shelf_router` | `test http` |
| CLI | dcli | `dcli args` | `test` |
| ライブラリ | — | — | `test flutter_lints` |

### pubspec.yaml 重要フィールド

- `environment.sdk`: `">=3.4.0 <4.0.0"`
- `environment.flutter`（Flutter のみ）: `">=3.22.0"`
- `publish_to`: `"none"`（公開しない場合）
- `flutter.uses-material-design`: `true`（Flutter）

## 設定ファイル

### analysis_options.yaml

Flutter プロジェクト:
```yaml
include: package:flutter_lints/flutter.yaml
linter:
  rules:
    prefer_const_constructors: true
    avoid_print: true
analyzer:
  errors:
    missing_return: error
```

Pure Dart プロジェクト:
```yaml
include: package:lints/recommended.yaml
```

### チーム規模別調整

- 個人: `package:lints/recommended.yaml` のみ
- 小規模: `package:flutter_lints/flutter.yaml` + カスタムルール数個
- 大規模: `strict: true` 相当 + `avoid_dynamic_calls`, `prefer_final_locals` 等を追加

## エントリポイント

| タイプ | パス | 内容 |
|--------|------|------|
| Flutter アプリ | `lib/main.dart` | `runApp(MyApp())` |
| dart_frog API | `routes/index.dart` | `Response onRequest(RequestContext context)` |
| shelf API | `bin/server.dart` | `shelf.serve(handler, host, port)` |
| CLI (dcli) | `bin/<name>.dart` | `main(List<String> args)` |
| ライブラリ | `lib/<name>.dart` | パブリック API エクスポート |

## テスト雛形

- Flutter: `test/widget/` に `*_test.dart`、`testWidgets()` でウィジェットテスト
- dart_frog: `test/routes/` に `*_test.dart`、`RequestContext` モック
- 最小構成: Flutter → `MaterialApp` レンダリングテスト、API → エンドポイント応答テスト
- 統合テスト (Flutter): `integration_test/` ディレクトリ

## Docker ガイド

- Flutter Web: `ghcr.io/cirruslabs/flutter:latest` → Nginx で静的配信
- dart_frog / shelf: `dart:stable` → マルチステージ（`dart compile exe`）→ `scratch` or `gcr.io/distroless/cc`
- `.dockerignore`: `.dart_tool`, `build`, `.git`, `.env*`, `.packages`
- AOT コンパイル: `dart compile exe bin/server.dart -o server` で単一バイナリ

### 開発用 Docker

- 開発用ベースイメージ: `dart:stable`
- Volume mount: `- .:/app` でソースコードをマウント、`pub-cache` は named volume で分離
- Hot-reload: `dart run --enable-vm-service`（dart_frog の場合は `dart_frog dev`）で自動再起動
- Dockerfile.dev: マルチステージ不要、dart pub get + dev server コマンド

## CI (GitHub Actions) ガイド

- Flutter セットアップ: `subosito/flutter-action@v2` + `flutter-version: '3.22'`
- Pure Dart: `dart-lang/setup-dart@v1`
- キャッシュ: `~/.pub-cache` をキャッシュ
- ステップ（Flutter）: `flutter pub get` → `dart analyze` → `dart format --set-exit-if-changed .` → `flutter test`
- ステップ（Dart）: `dart pub get` → `dart analyze` → `dart format --set-exit-if-changed .` → `dart test`

## 検証コマンド

| 操作 | Flutter | Pure Dart |
|------|---------|-----------|
| 依存インストール | `flutter pub get` | `dart pub get` |
| ビルド (Web) | `flutter build web` | — |
| ビルド (AOT) | — | `dart compile exe bin/main.dart` |
| テスト | `flutter test` | `dart test` |
| Lint | `dart analyze` | `dart analyze` |
| フォーマット確認 | `dart format --set-exit-if-changed .` | `dart format --set-exit-if-changed .` |
| 開発実行 | `flutter run` | `dart run bin/server.dart` |
