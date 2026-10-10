# Java スキャフォールディングガイド

## CLI ツール

| FW | コマンド | 備考 |
|----|---------|------|
| Spring Boot | `spring init --type=gradle-project --language=java --boot-version=3.3 --java-version=21 --dependencies=<deps> <name>` | Spring CLI 必要 |
| Spring Boot (curl) | `curl https://start.spring.io/starter.zip -d type=gradle-project -d language=java -d dependencies=<deps> -o <name>.zip` | CLI 不要 |
| Quarkus | `quarkus create app <groupId>:<artifactId> --extensions=<exts>` | Quarkus CLI 必要 |
| Micronaut | `mn create-app <name> --features=<features> --build=gradle_kotlin --lang=java` | Micronaut CLI 必要 |
| 汎用 | `gradle init --type java-application --dsl kotlin` | Gradle のみ |

## パッケージ定義

### 必須依存パッケージ

| タイプ | FW | dependencies | testDependencies |
|--------|-----|-------------|-----------------|
| API | Spring Boot | `spring-boot-starter-web` | `spring-boot-starter-test` |
| API | Quarkus | `quarkus-rest` | `quarkus-junit5 rest-assured` |
| API | Micronaut | `micronaut-http-server-netty` | `micronaut-test-junit5` |
| CLI | picocli | `info.picocli:picocli` | `junit-jupiter` |

### build.gradle.kts 重要フィールド

- `java.toolchain.languageVersion`: `JavaLanguageVersion.of(21)`
- `plugins`: `java`, `application`（CLI）, `org.springframework.boot`（Spring）
- `group` / `version`: プロジェクト識別子
- `repositories`: `mavenCentral()`

## 設定ファイル

### application.yml（Spring Boot）

- `server.port`: `8080`
- `spring.application.name`: プロジェクト名
- `logging.level.root`: `INFO`

### application.properties / application.yml 共通

- プロファイル: `application-dev.yml`, `application-prod.yml`
- テスト用: `src/test/resources/application-test.yml`

### Checkstyle 設定

- Google Java Style ベース: `google_checks.xml`
- チーム規模大: カスタムルール追加
- `build.gradle.kts`: `checkstyle { configFile = file("config/checkstyle/checkstyle.xml") }`

### チーム規模別調整

- 個人: Checkstyle なし、IDE フォーマッタのみ
- 小規模: google-java-format + 基本 Checkstyle
- 大規模: Checkstyle 厳格 + SpotBugs + PMD

## エントリポイント

| タイプ | パス | 内容 |
|--------|------|------|
| API (Spring) | `src/main/java/.../Application.java` | `@SpringBootApplication` + `main()` |
| API (Quarkus) | `src/main/java/.../GreetingResource.java` | `@Path` リソースクラス |
| CLI (picocli) | `src/main/java/.../App.java` | `@Command` + `Callable<Integer>` |
| ライブラリ | `src/main/java/.../<Name>.java` | パブリック API クラス |

## テスト雛形

- ファイル配置: `src/test/java/<package>/` に `*Test.java`
- Spring Boot: `@SpringBootTest` + `MockMvc`
- Quarkus: `@QuarkusTest` + RestAssured
- 最小構成: コンテキスト読み込みテスト + ヘルスチェックテスト

## Docker ガイド

- ベースイメージ: `eclipse-temurin:21-jre-jammy`（本番）/ `eclipse-temurin:21-jdk-jammy`（ビルド）
- マルチステージ: `builder`（Gradle ビルド）→ `runner`（JAR 実行）
- Gradle キャッシュ: `build.gradle.kts` と `settings.gradle.kts` を先にコピー
- `.dockerignore`: `.gradle`, `build`, `.git`, `.env*`

### 開発用 Docker

- 開発用ベースイメージ: `eclipse-temurin:21`（JDK フル）
- Volume mount: `- .:/app` でソースコードをマウント、`gradle-cache` は named volume で分離
- Hot-reload: `./gradlew bootRun`（Spring DevTools による自動再起動）
- Dockerfile.dev: マルチステージ不要、Gradle Wrapper + 依存解決 + bootRun コマンド

## CI (GitHub Actions) ガイド

- Java セットアップ: `actions/setup-java@v4` + `distribution: 'temurin'` + `java-version: '21'`
- Gradle キャッシュ: `actions/setup-java` の `cache: 'gradle'`
- ステップ: `./gradlew check` → `./gradlew test` → `./gradlew build`
- Gradle Wrapper コミット: `gradlew`, `gradlew.bat`, `gradle/wrapper/` を VCS に含める

## 検証コマンド

| 操作 | コマンド |
|------|---------|
| 依存解決 | `./gradlew dependencies` |
| ビルド | `./gradlew build` |
| テスト | `./gradlew test` |
| Lint | `./gradlew checkstyleMain` |
| 実行 | `./gradlew bootRun`（Spring）/ `./gradlew run`（汎用） |
| クリーン | `./gradlew clean` |
