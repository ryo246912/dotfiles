# Kotlin スキャフォールディングガイド

## CLI ツール

| FW | コマンド | 備考 |
|----|---------|------|
| Ktor | `ktor generate --project-name=<name> --features=<features>` | Ktor CLI または start.ktor.io からダウンロード |
| Ktor (curl) | `curl 'https://start.ktor.io/project/generate?...' -o <name>.zip` | CLI 不要 |
| Spring Boot (Kotlin) | `spring init --type=gradle-project --language=kotlin --java-version=21 --dependencies=<deps> <name>` | Spring CLI |
| 汎用 | `gradle init --type kotlin-application --dsl kotlin` | Gradle のみ |

## パッケージ定義

### 必須依存パッケージ

| タイプ | FW | dependencies | testDependencies |
|--------|-----|-------------|-----------------|
| API | Ktor | `ktor-server-core ktor-server-netty ktor-server-content-negotiation ktor-serialization-kotlinx-json` | `ktor-server-test-host kotlin-test-junit5` |
| API | Spring Boot | `spring-boot-starter-web` | `spring-boot-starter-test` |
| CLI | clikt | `com.github.ajalt.clikt:clikt` | `kotlin-test-junit5` |
| ライブラリ | — | `kotlin-stdlib` | `kotlin-test-junit5` |

### build.gradle.kts 重要フィールド（Java との差分）

- `plugins`: `kotlin("jvm")`, `kotlin("plugin.serialization")`（Ktor）
- `kotlin.jvmToolchain(21)`
- Ktor: `application { mainClass.set("com.example.ApplicationKt") }`
- Spring: `kotlin("plugin.spring")` プラグイン追加

## 設定ファイル

### Kotlin コンパイラ設定（build.gradle.kts）

- `kotlin.compilerOptions.jvmTarget`: `JvmTarget.JVM_21`
- `kotlin.compilerOptions.allWarningsAsErrors`: `true`（チーム規模大）
- `kotlin.compilerOptions.freeCompilerArgs`: `["-Xjsr305=strict"]`（Spring）

### テスト設定

- JUnit 5: `tasks.test { useJUnitPlatform() }`
- Kover（カバレッジ）: `plugins { id("org.jetbrains.kotlinx.kover") }`

### ktlint + detekt 設定

ktlint（フォーマッタ）:
- Gradle プラグイン: `org.jlleitschuh.gradle.ktlint`
- デフォルトルールセットで十分

detekt（静的解析）:
- Gradle プラグイン: `io.gitlab.arturbosch.detekt`
- 設定ファイル: `detekt.yml`
- チーム規模別: 個人=デフォルト、大規模=`complexity` ルール厳格化

## エントリポイント

| タイプ | パス | 内容 |
|--------|------|------|
| API (Ktor) | `src/main/kotlin/.../Application.kt` | `embeddedServer(Netty)` + モジュール設定 |
| API (Ktor) | `src/main/kotlin/.../plugins/Routing.kt` | ルーティング定義 |
| API (Spring) | `src/main/kotlin/.../Application.kt` | `@SpringBootApplication` + `runApplication<>()` |
| CLI (clikt) | `src/main/kotlin/.../Main.kt` | `CliktCommand` サブクラス |
| ライブラリ | `src/main/kotlin/.../<Name>.kt` | パブリック API |

## テスト雛形

- ファイル配置: `src/test/kotlin/<package>/` に `*Test.kt`
- Ktor: `testApplication { }` DSL でサーバーテスト
- Spring: `@SpringBootTest` + `MockMvc`（Java と共通）
- 最小構成: アプリケーション起動テスト + ルーティングテスト

## Docker ガイド

- ベースイメージ: Java と共通（`eclipse-temurin:21-jre-jammy`）
- マルチステージ: `builder`（Gradle ビルド）→ `runner`（JAR / fat JAR 実行）
- Ktor: `ktor-server-cio` で軽量 fat JAR 生成（`id("io.ktor.plugin")` + `ktor { fatJar {} }`）
- `.dockerignore`: `.gradle`, `build`, `.git`, `.env*`

### 開発用 Docker

- 開発用ベースイメージ: `eclipse-temurin:21`（JDK フル、Java と共通）
- Volume mount: `- .:/app` でソースコードをマウント、`gradle-cache` は named volume で分離
- Hot-reload: `./gradlew run --continuous`（Ktor）/ `./gradlew bootRun`（Spring Boot Kotlin）で自動再起動
- Dockerfile.dev: マルチステージ不要、Gradle Wrapper + 依存解決 + run コマンド

## CI (GitHub Actions) ガイド

- Java セットアップ: Java と共通（`actions/setup-java@v4`）
- Gradle キャッシュ: `cache: 'gradle'`
- ステップ: `./gradlew ktlintCheck` → `./gradlew detekt` → `./gradlew test` → `./gradlew build`
- Kover レポート: `./gradlew koverXmlReport`

## 検証コマンド

| 操作 | コマンド |
|------|---------|
| 依存解決 | `./gradlew dependencies` |
| ビルド | `./gradlew build` |
| テスト | `./gradlew test` |
| Lint（ktlint） | `./gradlew ktlintCheck` |
| 静的解析（detekt） | `./gradlew detekt` |
| カバレッジ | `./gradlew koverXmlReport` |
| 実行 (Ktor) | `./gradlew run` |
| 実行 (Spring) | `./gradlew bootRun` |
