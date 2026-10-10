---
name: dev-init
description: This skill should be used when the user asks to "dev-init", "技術スタックを選定", "新規プロジェクト初期化", "initialize tech stack", "プロジェクトをセットアップ", "setup project", "scaffold project", "プロジェクト作成", "tech stackを決める". インタラクティブなヒアリングでプロジェクトの技術スタックを決定し、dev-context互換のコンテキストファイルを生成する。承認制でプロジェクトスキャフォールディングも実行可能。
---

# Dev Init

インタラクティブなヒアリングを通じてプロジェクトの技術スタックを決定し、`docs/dev/context.md` を生成する。新規プロジェクトやまだ構成が固まっていないプロジェクト向け。承認後にプロジェクトの骨格ファイル（package.json、設定ファイル、ディレクトリ構造等）も生成可能。

既存プロジェクトの自動分析には `dev-context` を使用する。

## 前提知識

### dev-context との関係

```
dev-init（新規向け・対話型）  →  docs/dev/context.md
                             →  プロジェクトファイル群（承認制）
                             →  CLAUDE.md（Phase 6）
dev-context（既存向け・自動型）→  docs/dev/context.md
         ↓
dev-plan → dev-impl → dev-verify
                  ↘ dev-debug（必要時）
```

- 出力フォーマットは `dev-context` と完全互換
- 後続の dev-plan / dev-impl / dev-verify / dev-debug がそのまま参照可能

### 信号機システム

生成するコンテキストファイル・スキャフォールディング結果の各項目に確信度を付与する:

- 🔵 **前工程指示**: ユーザーが明示的に選択した情報
- 🟡 **妥当な推測**: 選択結果から推論した補足情報（パッケージマネージャ、Linter等）
- 🔴 **AI推論補完**: 情報不足でAIが仮置きした情報、テンプレート未対応言語の生成ファイル

## ワークフロー

### Phase 1: 既存プロジェクト検出

以下のファイルの存在を確認する:

1. `docs/dev/context.md` — 既存コンテキスト
2. `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `build.gradle`, `pom.xml`, `pubspec.yaml`, `build.gradle.kts` — パッケージ定義

> **Note:** `CLAUDE.md` の存在確認は Phase 5d（スキャフォールディング時）または Phase 6a-1（CLAUDE.md のみ生成時）で実施する。

**分岐ロジック:**

- `context.md` が存在する場合 → AskUserQuestion で「上書き更新 / 別名保存 / 中止」を確認。別名保存時のファイル名: `context.md.backup.YYYY-MM-DD`
- 「中止」選択時 → 「dev-init を終了しました。既存の context.md を維持します。」と表示してスキルを終了する
- パッケージ定義が存在する場合 → 「既存プロジェクトを検出。`dev-context`（自動分析）を推奨しますが、対話型で進めますか？」と確認
- いずれもない場合 → Phase 2 へ進む

> **同時存在時の優先順位:** `context.md` とパッケージ定義が両方存在する場合は、`context.md` の確認（上書き更新 / 別名保存 / 中止）を先に行う。「中止」が選択された場合はスキル終了。「上書き更新」または「別名保存」が選択された場合は、パッケージ定義の検出に関する確認（dev-context 推奨）を続けて行う。

### Phase 2: プロジェクト基本情報ヒアリング

AskUserQuestion ツールで以下を順次ヒアリングする。各質問は1問ずつ提示し、前の回答を次の質問の選択肢構成に反映する。

#### Q1: プロジェクトカテゴリ（大分類）

| 選択肢 | 説明 |
|--------|------|
| Webアプリケーション | ブラウザ向け/モバイル向けWebアプリ（フロントエンド含む） |
| サーバーサイド | API・バッチ処理・分散処理サービス |
| ツール/スクリプト | CLI・GAS等の単機能ツール |
| ライブラリ/パッケージ | 他プロジェクトから利用されるライブラリ |

#### Q2: プロジェクトタイプ（詳細分類）

Q1 の回答に応じて条件分岐する。ライブラリ/パッケージの場合は Q2 をスキップし自動確定する。

| Q1 の回答 | Q2 の選択肢 |
|-----------|------------|
| Webアプリケーション | フルスタック（一体型） / 3層アーキテクチャ（TypeScriptフロント+API+DB） / BFFアーキテクチャ（UI+BFF+サービス+DB） |
| サーバーサイド | APIサーバー / バッチ処理 / マイクロサービス / イベント駆動 |
| ツール/スクリプト | CLIツール / GAS（Google Apps Script） |
| ライブラリ/パッケージ | Q2 スキップ（自動確定） |

> **3層アーキテクチャ選択時の自動通知**: Q2回答直後、Q5に進む前に以下を表示する:
> 「3層アーキテクチャのため、以下が自動設定されます: フロントエンド言語: TypeScript（固定） / プロジェクト構成: モノレポ（packages/frontend + packages/backend + packages/shared）」

> **BFFアーキテクチャ選択時の自動通知**: Q2回答直後、Q3に進む前に以下を表示する:
> 「BFFアーキテクチャのため、以下が自動設定されます: プロジェクト構成: モノレポ」

#### Q3: UIターゲット（BFF のみ）

BFFアーキテクチャ選択時のみ質問する。他のタイプではスキップ。

| 選択肢 | 説明 |
|--------|------|
| Webのみ | ブラウザ向けWebアプリ |
| モバイルのみ | iOS/Android モバイルアプリ |
| Web + モバイル | 両方に対応（BFFで共通API提供） |

> モバイル選択時のフレームワークは、Q5a の言語選択に応じた推奨を提示する（Dart → Flutter(Recommended)/Other、TypeScript(RN) → React Native(Recommended)/Expo/Other）

> BFFアーキテクチャ選択時、Q3の後にQ4（サービス層構成: 単一サービス/複数サービス）を質問する。詳細はQ4セクション参照。

#### Q4: タイプ固有質問

プロジェクトタイプに応じた追加質問を行う。バッチ処理・マイクロサービス・イベント駆動ではQ6の前（Q5の後）に実施し、BFFではQ3の直後に実施し、GASではQ2の直後（Q5/Q6スキップのため）に実施する。該当タイプ以外ではスキップする。

**Q4: サービス層構成（BFF のみ）**

> BFFでは本質問をQ3の直後（技術選定の前）に実施する。

| 選択肢 | 説明 |
|--------|------|
| 単一サービス | BFF + 1サービスで開始。後から分割可能 |
| 複数サービス | 初期から services/service-a, services/service-b 等の構成 |

**Q4b: 初期サービス構成（BFF 複数サービス選択時のみ）**

| 選択肢 | 説明 |
|--------|------|
| 2サービス（デフォルト） | service-a, service-b の2サービスで開始 |
| カスタム | サービス名をカンマ区切りで入力（例: user-service, order-service）。kebab-case |

**Q4: スケジューリング方式（バッチ処理のみ）**

| 選択肢 | 説明 |
|--------|------|
| cron / OS スケジューラ | システムの cron や systemd timer で定期実行 |
| クラウドスケジューラ | Cloud Scheduler / EventBridge 等で実行 |
| フレームワーク内蔵 | BullMQ / Celery Beat 等ジョブキュー型 |

**Q4: サービス間通信（マイクロサービスのみ）**

| 選択肢 | 説明 |
|--------|------|
| REST API | HTTP ベースの同期通信 |
| gRPC | Protocol Buffers ベースの高効率通信 |
| メッセージキュー | 非同期メッセージング（Kafka / RabbitMQ 等） |

**Q4c: メッセージブローカー（マイクロサービスでメッセージキュー選択時のみ）**

> マイクロサービスの Q4 で「メッセージキュー」を選択した場合のみ質問する。

| 選択肢 | 説明 |
|--------|------|
| Apache Kafka | 高スループット・ストリーム処理 |
| RabbitMQ | 汎用メッセージブローカー |
| AWS SQS + SNS | AWSマネージドキュー |
| Redis Pub/Sub | 軽量・リアルタイム |

**Q4b: 初期サービス構成（マイクロサービスのみ）**

> マイクロサービスではQ4（サービス間通信）→ Q4b（初期サービス構成）→ Q6 の順で実施する。アーキテクチャ設計（通信方式+サービス構成）を一括で聞いた後、技術選定（FW）に進む。

| 選択肢 | 説明 |
|--------|------|
| 2サービス（デフォルト） | service-a, service-b の2サービスで開始 |
| 単一サービス | 1サービスで開始し、後から追加 |
| カスタム | サービス数・名前を自由入力 |

**Q4: メッセージブローカー（イベント駆動のみ）**

| 選択肢 | 説明 |
|--------|------|
| Apache Kafka | 高スループット・ストリーム処理 |
| RabbitMQ | 汎用メッセージブローカー |
| AWS SQS + SNS | AWSマネージドキュー |
| Redis Pub/Sub | 軽量・リアルタイム |

**Q4: GAS デプロイ形態（GAS のみ）**

| 選択肢 | 説明 |
|--------|------|
| スタンドアロン | 独立したスクリプトプロジェクト |
| スプレッドシート連携 | Google Sheets のカスタム関数・メニュー |
| Webアプリ | doGet/doPost による HTTP エンドポイント |

#### Q5: 言語選択

プロジェクトタイプに応じて質問構成が変わる。

**共通の言語選択肢:**

| 選択肢 | 説明 |
|--------|------|
| TypeScript | Node.js/Deno/Bun 向け |
| Python | FastAPI/Django/Flask 等 |
| Rust | 高パフォーマンス・システム |
| Go | マイクロサービス・CLI |
| Java | Spring Boot/Quarkus 等 |
| Kotlin | Ktor/Spring Boot(Kotlin) 等 |
| Dart | Flutter/dart_frog 等 |

**Q5 の条件分岐:**

- **GAS 選択時**: Q5 をスキップし TypeScript を自動選定
- **3層アーキテクチャ選択時**: Q5 のみ質問。質問文は「バックエンドの主要言語を選択してください」。UI層は TypeScript 自動選定
- **BFFアーキテクチャ選択時**: Q5a/Q5b/Q5c の3段階に分割（下記参照）
- **その他のタイプ**: Q5 のみ質問（「主要言語を選択してください」）

**BFF の Q5 分割:**

各レイヤーの言語選択（Q5a/Q5b/Q5c）後、対応するフレームワーク（Q6a/Q6b/Q6c）を連続して質問する。UI層（Q5a→Q6a）→ BFF層（Q5b→Q6b）→ サービス層（Q5c→Q6c）の順で進む。

- **Q5a（UI層言語）**: Q3（UIターゲット）に応じて分岐
  - Webのみ → TypeScript 自動選定（スキップ）
  - モバイルのみ → 質問（Dart / TypeScript(React Native)）
  - Web+モバイル → Web は TypeScript 自動選定、モバイル側を質問（Dart / TypeScript(React Native)）
- **Q5b（BFF層言語）**: 全言語から選択。TypeScript に「（Recommended）」ラベル
- **Q5c（サービス層言語）**: 全言語から選択（従来と同等）

### Phase 3: 技術詳細ヒアリング

Phase 2 の回答に基づいて動的に質問を構成する。`references/tech-recommendations.md` の推奨マトリクスを参照し、言語×プロジェクトタイプに応じた選択肢を提示する。

> BFFアーキテクチャでは、各レイヤーの言語（Q5）とフレームワーク（Q6）をペアで連続して質問する。UI層（Q5a→Q6a）→ BFF層（Q5b→Q6b）→ サービス層（Q5c→Q6c）の順で進む。

> 3層アーキテクチャでは、Q5（バックエンド言語）→ Q6（バックエンドFW）を直結させた後、Q6a（フロントエンドFW）を質問する。この順序は「言語選択とFW選択の認知的連続性」を優先するため: バックエンドは言語+FWの2つの決断が必要な一方、フロントエンドはFWのみ（言語はTypeScript固定）のため、決断負荷が重い方を先に片付ける設計。

#### Q6: フレームワーク

言語とプロジェクトタイプの組み合わせに応じて、推奨マトリクスから選択肢を動的構成する。推奨表の「推奨1」を先頭に配置し、ラベルに「（Recommended）」を付与する。

- **ライブラリ/パッケージ**: Q6 をビルド/バンドラツールとして質問する。言語に応じた選択肢を提示:
  - TypeScript: tsup（Recommended）/ unbuild / rollup / tsc のみ
  - Python: hatchling（Recommended）/ setuptools / flit
  - Rust: スキップ（cargo 標準）
  - Go: スキップ（go build 標準）
  - Java: Gradle（Recommended）/ Maven
  - Kotlin: Gradle（Recommended）
  - Dart: スキップ（pub 標準）

**Q6 の条件分岐:**

- **3層アーキテクチャ**: Q6（バックエンドFW: Q5言語の直後に質問）+ Q6a（フロントエンドFW: TypeScript Webアプリの推奨マトリクスから）に分割
- **BFFアーキテクチャ**: Q6a/Q6b/Q6c の3段階に分割（下記参照）
- **GAS**: Q6 スキップ（clasp + esbuild を自動選定）
- **バッチ処理**: Q4（スケジューリング方式）の回答を考慮し、該当タイプの推奨マトリクスから構成
- **マイクロサービス**: Q4（サービス間通信）の回答を考慮し、該当タイプの推奨マトリクスから構成。gRPC選択時はgRPC対応FWを優先推奨する
- **イベント駆動**: Q4（メッセージブローカー）の回答に基づき、選択したブローカーに対応するクライアントライブラリ付きFWを推奨マトリクスから構成。推奨マトリクスの「イベント駆動」行から、Q4で選択したブローカーに対応するFW+ライブラリの組み合わせを提示する

**BFF の Q6 分割:**

各Q6はQ5と対になるレイヤーの言語選択直後に質問する（Q5a→Q6a→Q5b→Q6b→Q5c→Q6cの順）。

- **Q6a（UI FW）**: Q3（UIターゲット）× Q5a言語に応じた推奨マトリクスから
  - Webのみ → TypeScript Webアプリの推奨マトリクスから選択
  - モバイルのみ → Q5a言語に応じたモバイルFW推奨から選択（Q5a=Dart: Flutter(Recommended)/Other、Q5a=TypeScript(RN): React Native(Recommended)/Expo/Other）
  - Web+モバイル → Q6a を2問に分割: Q6a-mobile（Q5a言語のモバイルFW推奨から。Q5a の直後にペアで質問）+ Q6a-web（TypeScript WebアプリFW推奨マトリクスから）
- **Q6b（BFF FW）**: Q5b言語の BFF（BFF層）推奨マトリクスから
- **Q6c（サービス層FW）**: Q5c言語の BFF（サービス層）推奨マトリクスから

#### Q7: チーム規模・開発フェーズ

| 選択肢 | 説明 |
|--------|------|
| 個人・プロトタイプ | 迅速な立ち上げ優先 |
| 小規模チーム（2-5人） | バランス重視 |
| 中〜大規模チーム（6人以上） | 堅牢性・標準化重視 |

#### Q8: データベース

CLIツール・GAS・ライブラリ/パッケージ以外の場合に質問する。

| 選択肢 | 説明 |
|--------|------|
| PostgreSQL（Recommended） | 汎用RDBMS |
| SQLite | 軽量・組み込み |
| MongoDB | ドキュメントDB |
| なし | DB不要 |

#### Q9: テストフレームワーク

言語に応じて推奨表から選択肢を構成する。推奨デフォルトを先頭に配置する。

**Q9 の条件分岐:**

- **単一言語プロジェクト**（フルスタック / APIサーバー / バッチ処理 / マイクロサービス / イベント駆動 / CLIツール / GAS / ライブラリ）: Q5 言語の推奨テストFWから選択肢を構成（従来通り）
- **3層アーキテクチャ（Q5 = TypeScript の場合）**: 全層 TypeScript のため、Vitest を推奨デフォルトとして1問で質問（従来通り）
- **3層アーキテクチャ（Q5 ≠ TypeScript の場合）**: 各層の言語からテストFW推奨表を自動引き当てし、一覧を提示して確認を求める。質問文: 「テストフレームワーク（自動選定）: フロントエンド (TypeScript): Vitest / バックエンド ([Q5言語]): [推奨FW]。この構成でよろしいですか？」選択肢: 「この構成で進める（Recommended）」/「変更する」。「変更する」選択時は各層のテストFWを個別に質問する
- **BFF（全層同一言語の場合）**: 1問で質問（従来通り）。同一言語判定: Q3=Webのみの場合は TypeScript(自動) + Q5b + Q5c が全てTypeScriptかで判定。Q3=モバイルのみの場合は Q5a + Q5b + Q5c で判定。Q3=Web+モバイルの場合は TypeScript(Web自動) + Q5a + Q5b + Q5c が全て同一かで判定（Web側がTypeScript固定のため、全層同一はQ5a=TypeScript(RN) かつ Q5b=TypeScript かつ Q5c=TypeScript の場合のみ成立）
- **BFF（混合言語の場合）**: 各層の言語からテストFW推奨表を自動引き当てし、一覧を提示して確認を求める。質問文はQ3の回答に応じて構成する:
  - Q3=Webのみ/モバイルのみ: 「テストフレームワーク（自動選定）: UI層 ([Q5a言語]): [推奨FW] / BFF層 ([Q5b言語]): [推奨FW] / サービス層 ([Q5c言語]): [推奨FW]。この構成でよろしいですか？」
  - Q3=Web+モバイル: 「テストフレームワーク（自動選定）: UI層-Web (TypeScript): Vitest / UI層-Mobile ([Q5a言語]): [推奨FW] / BFF層 ([Q5b言語]): [推奨FW] / サービス層 ([Q5c言語]): [推奨FW]。この構成でよろしいですか？」
  - 選択肢: 「この構成で進める（Recommended）」/「変更する」

**Q9「変更する」選択時のサブフロー:**

- **3層アーキテクチャ**: 以下の2問を順次質問する
  1. Q9-front: フロントエンドのテストFW（TypeScript推奨表から選択肢構成。変更前のデフォルト値に「(現在の選定)」ラベル付与）
  2. Q9-back: バックエンドのテストFW（Q5言語推奨表から選択肢構成）
- **BFF（Q3=Webのみ/モバイルのみ）**: 以下の3問を順次質問する
  1. Q9-ui: UI層のテストFW（Q5a言語推奨表から）
  2. Q9-bff: BFF層のテストFW（Q5b言語推奨表から）
  3. Q9-service: サービス層のテストFW（Q5c言語推奨表から）
- **BFF（Q3=Web+モバイル）**: 以下の4問を順次質問する
  1. Q9-ui-web: UI層-WebのテストFW（TypeScript推奨表から）
  2. Q9-ui-mobile: UI層-MobileのテストFW（Q5a言語推奨表から）
  3. Q9-bff: BFF層のテストFW（Q5b言語推奨表から）
  4. Q9-service: サービス層のテストFW（Q5c言語推奨表から）

#### Q10: 開発環境のDocker化

CLIツール・GAS・ライブラリ/パッケージ以外の場合に質問する。

| 選択肢 | 説明 |
|--------|------|
| Docker開発環境（Recommended） | 全サービスをdocker-composeで管理。DB・テストツール含む |
| Dockerなし | ローカルにランタイムをインストールして開発 |

- Docker選択時、Q8でDB選択済みなら自動でDBサービスを含める
- Webアプリ + Docker選択時、playwrightサービスも自動追加
- マイクロサービス・イベント駆動・BFFの場合、Docker 選択肢の説明を「Strongly Recommended」に変更

#### Q11: 追加ツール・要件（複数選択）

| 選択肢 | 説明 |
|--------|------|
| CI/CD（GitHub Actions） | 自動テスト・デプロイ |
| モノレポ構成 | 複数パッケージの統合管理 |

**Q11 の条件分岐:**

- **3層アーキテクチャ**: 「モノレポ構成」を自動選択（構造上必須のため質問不要）。Q11 の質問文に「※ モノレポ構成は3層アーキテクチャのため自動適用されます」と明記する
- **BFFアーキテクチャ**: 「モノレポ構成」を自動選択（構造上必須のため質問不要）。Q11 の質問文に「※ モノレポ構成はBFFアーキテクチャのため自動適用されます」と明記する
- **マイクロサービス**: 「モノレポ構成」に「(Recommended)」ラベル付与
- **ライブラリ/パッケージ**: 「モノレポ構成」に加え、「パッケージ公開設定（npm publish / cargo publish / PyPI upload 等）」を選択肢に追加する
- **CLIツール**: 「モノレポ構成」を除外し、「CI/CD（GitHub Actions）」のみ提示する
- **GAS**: CLIツールと同様、「モノレポ構成」を除外し、「CI/CD（GitHub Actions）」のみ提示する

> **Note:** Linter/Formatter および PM（パッケージマネージャ）は Q5（言語）の選択に基づき常に自動選定される（`references/tech-recommendations.md` の Linter/Formatter 推奨表・PM 推奨表参照）。Q5 回答後、次の質問に進む前に「言語選択に基づく自動設定: Linter: [値] / Formatter: [値] / PM: [値]」を通知する。GAS の場合は Q2 直後のまとめ通知に含まれるため個別通知は不要。

> **Note:** 混合言語 BFF では pnpm ワークスペースではなく Makefile + Docker Compose ベースのモノレポ構成になる場合がある。Q5a・Q5b・Q5c が全て同一言語（TypeScript）の場合のみ pnpm ワークスペースを使用する。

### 質問フロー一覧（全体像）

```
フルスタック:       Q1→Q2→Q5→Q6→Q7→Q8→Q9→Q10→Q11
3層Web:            Q1→Q2→Q5→Q6→Q6a→Q7→Q8→Q9→Q10→Q11
BFF:               Q1→Q2→Q3→Q4→Q5a→Q6a→Q5b→Q6b→Q5c→Q6c→Q7→Q8→Q9→Q10→Q11
APIサーバー:        Q1→Q2→Q5→Q6→Q7→Q8→Q9→Q10→Q11
バッチ処理:         Q1→Q2→Q5→Q4→Q6→Q7→Q8→Q9→Q10→Q11
マイクロサービス:   Q1→Q2→Q5→Q4→Q4b→Q6→Q7→Q8→Q9→Q10→Q11
イベント駆動:       Q1→Q2→Q5→Q4→Q6→Q7→Q8→Q9→Q10→Q11
CLIツール:          Q1→Q2→Q5→Q6→Q7→Q9→Q11
GAS:                Q1→Q2→Q4→Q7→Q9→Q11
ライブラリ:         Q1→Q5→Q6→Q7→Q9→Q11
```
> マイクロサービスでメッセージキュー選択時、Q4の後にQ4cでブローカーを指定
> BFF複数サービス選択時、Q4の後にQ4bでサービス構成を指定
> BFF Web+モバイル時、Q6a は Q6a-mobile + Q6a-web の2問に分割

> 非BFFタイプの Q5 は「主要言語」として1問のみ質問。3層アーキテクチャでは「バックエンドの主要言語」として質問する。BFFでは Q5a/Q5b/Q5c の3段階に分割される。

> 非BFF・非3層タイプの Q6 は「フレームワーク」として1問のみ質問。推奨マトリクスの該当タイプ×Q5言語の行から選択肢を構成する。3層アーキテクチャでは Q6（バックエンドFW）+ Q6a（フロントエンドFW）に分割される。BFFでは Q6a/Q6b/Q6c の3段階に分割される。ライブラリ/パッケージではビルド/バンドラツールとして質問する。

### Phase 4: コンテキスト生成

全ヒアリング結果を統合し、`docs/dev/context.md` を生成する。

#### 4a. ディレクトリ準備

```bash
mkdir -p "$(git rev-parse --show-toplevel)/docs/dev"
```

#### 4b. context.md 生成

`dev-context` の `references/context-template.md`（`.claude/skills/dev-context/references/context-template.md`）と同じフォーマットで生成する。テンプレートの各セクションを以下のように埋める:

- **Tech Stack**: Q5（言語）、Q6（フレームワーク）、PM は推奨表からデフォルト選定。3層の場合はフロントエンド・バックエンド各層の言語・FW情報を記載。BFFの場合はUI層（Q5a/Q6a）、BFF層（Q5b/Q6b）、サービス層（Q5c/Q6c）の各層情報を記載。PM は各層の言語に応じた推奨 PM をそれぞれ選定
- **Test Framework**: Q9 の選択結果、テストコマンドは推奨表から自動設定
- **Project Structure**: 言語×タイプに応じた推奨ディレクトリ構造を `references/tech-recommendations.md` から取得（3層/BFF/バッチ/マイクロサービス/イベント駆動/GAS の新テンプレートを含む）
- **Coding Conventions**: 言語のデフォルト規約を推奨表から設定（🟡マーク）
- **Key Entry Points**: ディレクトリ構造テンプレートに基づく想定エントリポイント（🟡マーク）
- **Build & Run**: 推奨表からデフォルトコマンドを設定
- **Docker Environment**: Q10 で Docker 開発環境を選択した場合、`references/docker-dev-templates.md` を参照して Docker Environment セクションを生成。Docker 選択時は Build & Run セクションのコマンドを `docker compose exec app <command>` 形式に変更
- **Additional Notes**: Q11 の追加ツール情報、チーム規模に応じた注意点、タイプ固有質問（Q3/Q4）の回答内容を反映。混合言語 BFF では shared の型定義を言語中立な形式（OpenAPI / Protocol Buffers）で管理することを推奨する旨を追記

ヘッダーは以下のように記載する:

```markdown
> Generated by dev-init. Last updated: YYYY-MM-DD
> Confidence: 🔵 = user selected, 🟡 = inferred from selection, 🔴 = AI assumption
```

#### 4c. 結果サマリーと次のステップ

生成完了後、以下を表示する:

1. 選択した技術スタックのサマリー（表形式）
2. 推奨ディレクトリ構造（`references/tech-recommendations.md` から該当テンプレート）
3. 次のステップの案内（以下の3択を提示）:
   - Phase 5（スキャフォールディング + CLAUDE.md 生成）へ進む
   - Phase 5 をスキップして Phase 6（CLAUDE.md のみ生成）へ進む
   - Phase 5・6 をスキップ（context.md のみで終了）

### Phase 5: プロジェクトスキャフォールディング（承認制）

#### 5a. スキャフォールディング実行確認

Phase 4 完了後、AskUserQuestion で確認する:
- 「プロジェクトの骨格ファイル（設定ファイル、エントリポイント、CLAUDE.md 等）を生成しますか？」
- 選択肢: 「生成する」/「スキップして CLAUDE.md のみ生成（Phase 6）」/「スキップ（context.md のみで終了）」
- 「スキップして CLAUDE.md のみ生成」の場合 → Phase 6 へ進む
- 「スキップ」の場合 → `dev-plan` での要件定義・タスク分解を案内して終了（従来動作）

#### 5b. 生成方式の決定

選択した言語の scaffolding ファイル（`references/<lang>-scaffolding.md`）を参照:

- CLI ツールがある FW の場合 → AskUserQuestion で「CLI 利用 / 直接生成」を提示
- CLI がない場合 → 直接生成
- scaffolding ファイルが存在しない言語 → 直接生成（全ファイルに 🔴 マーク + 「テンプレート未対応」警告表示）

#### 5c. ファイル一覧の構築と承認

scaffolding ファイルを参照し、生成予定ファイルのツリーを構築する。

**常に生成するファイル:**
- `.gitignore`, `README.md`
- パッケージ定義ファイル（package.json / Cargo.toml / go.mod / pyproject.toml / build.gradle.kts / pubspec.yaml）
- コンパイラ/ランタイム設定ファイル
- エントリポイントファイル
- テストファイル（スモークテスト）
- Linter/Formatter 設定ファイル（Q5 の言語選択に基づき自動選定。`references/tech-recommendations.md` の推奨表に従う）
- `CLAUDE.md` — プロジェクトルールと開発コマンドの指示書（`references/claudemd-template.md` に基づく）

**モノレポ構成時（3層Web / BFF / マイクロサービス）に追加生成:**
- サブパッケージ `CLAUDE.md` — 各パッケージルートに配置（`references/claudemd-template.md` の「サブパッケージ CLAUDE.md テンプレート構造」に基づく）。生成対象は後述の 5d のパッケージ判定ロジックに従う

**Q10 Docker開発環境選択時のみ生成:**
- `docker-compose.yml` — 開発環境全体定義（`references/docker-dev-templates.md` を参照して構成）
- `Dockerfile.dev` — 開発用Dockerfile（hot-reload対応、volume mount前提）
- `Dockerfile` — デプロイ用（従来通り）
- `.dockerignore`

**Q11 選択時のみ生成:**
- CI/CD 選択時: `.github/workflows/ci.yml`

AskUserQuestion でファイルツリーを提示 → 「生成する / ファイルを修正する / 中止する」

#### 5d. ファイル生成実行

- **CLI 選択時**: scaffolding ファイルに記載された非対話フラグ付きで CLI 実行 → 不足ファイルを補完生成
- **直接生成時**: ディレクトリ作成 → パッケージ定義 → 設定ファイル → エントリポイント → テストファイル → Docker/CI → .gitignore/README の順で生成
- 各ファイル生成時に scaffolding ファイルの決定ガイド（依存パッケージ表、設定項目等）を参照
- **CLAUDE.md 生成**: `references/claudemd-template.md` と Q1-Q11 の回答に基づき、スキャフォールディングの最後に CLAUDE.md を生成する。既存の CLAUDE.md がある場合は Phase 1 で検出済みのため、上書き/バックアップ/スキップの判断に従う。生成ルールは Phase 6 の 6b に準拠する
- **サブパッケージ CLAUDE.md 生成**: モノレポ構成時、ルート CLAUDE.md 生成後に各サブパッケージの CLAUDE.md を生成する。生成ルールは Phase 6 の 6b-2 に準拠する。パッケージ判定ロジック:

| アーキテクチャ | Q3の回答 | 生成対象パッケージ | 生成しない |
|--------------|---------|-----------------|-----------|
| 3層Web | — | `packages/frontend/`, `packages/backend/` | `packages/shared/` |
| BFF（単一） | Webのみ | `packages/web-ui/`, `packages/bff/`, `packages/service/` | `packages/shared/` |
| BFF（単一） | モバイルのみ | `packages/mobile-ui/`, `packages/bff/`, `packages/service/` | `packages/shared/` |
| BFF（単一） | Web+モバイル | `packages/web-ui/`, `packages/mobile-ui/`, `packages/bff/`, `packages/service/` | `packages/shared/` |
| BFF（複数） | Webのみ | `packages/web-ui/`, `packages/bff/`, 各 `services/<name>/` | `packages/shared/` |
| BFF（複数） | モバイルのみ | `packages/mobile-ui/`, `packages/bff/`, 各 `services/<name>/` | `packages/shared/` |
| BFF（複数） | Web+モバイル | `packages/web-ui/`, `packages/mobile-ui/`, `packages/bff/`, 各 `services/<name>/` | `packages/shared/` |
| マイクロサービス | — | 各 `services/<name>/` | `packages/shared/` |

> **Note:** マイクロサービスで Q11 モノレポ未選択の場合、サブパッケージ生成は発動しない

#### 5e. 依存インストールと検証

scaffolding ファイルの「検証コマンド」セクションに従い:

**Q10 で Docker 開発環境を選択した場合:**
- `docker compose up -d` でコンテナを起動（未起動の場合）
- 以下の検証コマンドはすべて `docker compose exec app <command>` 形式で実行

**検証手順:**
1. パッケージマネージャで依存インストール
2. テスト実行
3. ビルド確認
4. Lint 確認
5. 失敗時 → エラー分析 → 修正 → 再実行（最大3リトライ）
6. 3回失敗 → 残存問題を 🔴 でレポートに報告

#### 5f. スキャフォールディングレポート

生成完了後、以下を表示する:

1. 生成ファイル一覧 + 確信度（🔵🟡🔴）— CLAUDE.md・サブパッケージ CLAUDE.md を含む
2. 検証結果（依存インストール / ビルド / テスト / Lint）
3. ルート CLAUDE.md の生成結果（行数、含まれるセクション一覧）
4. サブパッケージ CLAUDE.md の生成結果（各パッケージのパス・行数）。`packages/shared/` は「手動追加可能」と案内
5. 「必要に応じて CLAUDE.md を手動編集し、プロジェクト固有のルールを追加してください」の案内
6. 次のステップ: `dev-plan` での要件定義・タスク分解の案内

### Phase 6: CLAUDE.md 生成（スキャフォールディングをスキップした場合）

Phase 5 でスキャフォールディングを実行した場合、CLAUDE.md は Phase 5d で自動生成されるため、このフェーズはスキップする。Phase 5 をスキップした場合（context.md のみ生成した場合）にのみ、このフェーズを実行する。

#### 6a-1. ルート CLAUDE.md 存在確認

プロジェクトルートの `CLAUDE.md` の有無を確認する。

- `CLAUDE.md` が存在しない場合 → 6b へ進む
- `CLAUDE.md` が存在する場合 → AskUserQuestion で以下を確認:
  - 「上書き」— 既存ファイルを新しい内容で置き換え
  - 「バックアップ保存して新規作成」— `CLAUDE.md.backup.YYYY-MM-DD` にリネーム後、新規作成
  - 「スキップ」— CLAUDE.md 生成をスキップし、6d の最終サマリーへ

#### 6a-2. サブパッケージ CLAUDE.md 存在確認

モノレポ構成（3層Web / BFF / マイクロサービス）の場合、5d のパッケージ判定ロジックに基づき各サブパッケージの `CLAUDE.md` の有無を確認する。

- サブパッケージ `CLAUDE.md` が1つも存在しない場合 → 6b-2 へ進む
- 一部または全部が存在する場合 → AskUserQuestion で以下を確認:
  - 「全て上書き」— 既存ファイルを新しい内容で置き換え
  - 「未作成のみ生成」— 既存のサブパッケージ CLAUDE.md はスキップし、未作成のもののみ生成
  - 「スキップ」— サブパッケージ CLAUDE.md 生成をスキップ

#### 6b-1. ルート CLAUDE.md 生成

`references/claudemd-template.md` と Q1-Q11 の回答から CLAUDE.md を生成する。各セクションの構成:

- **Project Overview**: Q1/Q2（プロジェクトタイプ）+ Q5（言語）+ Q6（フレームワーク）から1-2行で構成
- **Development Commands**: `references/claudemd-template.md` のコマンド導出テーブル + scaffolding ファイルからコマンドを導出。Q10 で Docker 選択時は `docker compose exec app` プレフィクスを付与し、Docker 操作コマンド（up/down/logs）も追加
- **Code Style**: `references/claudemd-template.md` の言語別デフォルト + Q7（チーム規模）で記載量・厳格度を調整
- **Project Rules**: Q6 フレームワーク固有ルール（ディレクトリ配置等）+ Q9 テスト規約 + Q10 Docker 規約 + Q11 追加ツール規約
- **Language**: 「日本語でコミュニケーションする。」

生成時の制約:
- **80行以内** に収める（`references/claudemd-template.md` の圧縮優先順位に従う）
- **指示的な言語** を使用する（「〜を使う」「〜しない」）
- **context.md の内容を重複させない**（詳細は context.md に委ね、コマンドとルールに集中）
- **信号機システムは使わない**（CLAUDE.md は指示書であり検出結果ではない）
- コマンドは **コピペ可能な正確なコマンド** を記載する

#### 6b-2. サブパッケージ CLAUDE.md 生成

モノレポ構成時、ルート CLAUDE.md 生成後に各サブパッケージの CLAUDE.md を生成する。`references/claudemd-template.md` の「サブパッケージ CLAUDE.md テンプレート構造」「サブパッケージ Development Commands 導出テーブル」「サブパッケージ Package Rules テンプレート」に基づく。

**生成対象パッケージの判定:**
- 5d のパッケージ判定ロジックに従い、アーキテクチャに応じた対象パッケージを特定する
- `packages/shared/` は生成しない（レポートに「手動追加可能」と案内）
- マイクロサービスで Q11 モノレポ未選択の場合は生成しない

**各サブパッケージ CLAUDE.md の構成:**
- **パッケージ名と役割**: パッケージ名（ディレクトリ名）+ 使用フレームワーク + 1行の役割説明
- **Development Commands**: `references/claudemd-template.md` の「サブパッケージ Development Commands 導出テーブル」からパッケージローカルコマンドを導出。Q10 Docker 選択時は `docker compose exec app` プレフィクスを付与
- **Code Style**（混合言語時のみ）: ルートと異なる言語のパッケージにのみ記載。同一言語判定: BFF の同一言語判定は Q3 の回答に応じて行う。Q3=Webのみの場合は TypeScript(自動) + Q5b + Q5c が全てTypeScriptかで判定。Q3=モバイルのみの場合は Q5a + Q5b + Q5c で判定。Q3=Web+モバイルの場合は TypeScript(Web自動) + Q5a + Q5b + Q5c が全て同一かで判定（Web側がTypeScript固定のため、全層同一はQ5a=TypeScript(RN) かつ Q5b=TypeScript かつ Q5c=TypeScript の場合のみ成立）。3層で Q5 が TypeScript なら同一言語、それ以外なら混合言語（Code Style 追加）
- **Package Rules**: `references/claudemd-template.md` の「サブパッケージ Package Rules テンプレート」からパッケージ役割に応じたルールを記載

**生成時の制約:**
- **30行以内** に収める（`references/claudemd-template.md` の「30行制限の圧縮ガイド」に従う）
- ルート CLAUDE.md と内容を **重複させない**（ルートに記載済みの共通ルールは省略）
- Language セクションは **記載しない**（ルートで定義済み）

#### 6c. 結果表示

生成完了後、以下を表示する:

1. ルート CLAUDE.md の行数と含まれるセクション一覧
2. サブパッケージ CLAUDE.md の生成結果（モノレポ構成時のみ）:
   - 各パッケージのパスと行数（例: `packages/frontend/CLAUDE.md` — 12行）
   - `packages/shared/` は「必要に応じて手動で CLAUDE.md を追加してください」と案内
3. 「必要に応じて CLAUDE.md を手動編集し、プロジェクト固有のルールを追加してください」の案内

#### 6d. 最終サマリー

全 Phase の統合サマリーを表示する:

1. 技術スタック概要（Q1-Q11 の結果要約）
2. 生成ファイル一覧（context.md、CLAUDE.md、スキャフォールディングファイル）
3. 次のステップ: `dev-plan` での要件定義・タスク分解の案内

## ルール・制約

- 全ての質問は **AskUserQuestion** ツールで提示する
- 質問は **1問ずつ順次** 提示し、前の回答を次の選択肢に反映する
- 出力フォーマットは `dev-context` の `context-template.md` と **完全互換**
- `context.md` は **500行以内** に収める
- Phase 4 までは `context.md` と `docs/dev/` のみ生成する
- Phase 5 はユーザーの **明示的な承認後にのみ** 実行する
- CLI 使用時は **非対話モード**（フラグ指定）のみ使用する
- 検証（5e）は **最大3リトライ** で打ち切る
- scaffolding ファイルが存在しない言語は全ファイルに **🔴 マーク必須**
- 生成する全ファイルは **500行以内** に収める
- 「Other」による自由入力を常に許容する（AskUserQuestion の標準機能）
- 既存の `docs/dev/plans/` 配下のファイルには影響を与えない
- 推奨マトリクスに該当しない言語・FWの組み合わせでも、ユーザー入力を尊重して context.md を生成する
- Bash コマンドはプロジェクトルートの **絶対パス** を使用する（`$(git rev-parse --show-toplevel)` でルートを取得）
- CLAUDE.md は **80行以内** に収める（`references/claudemd-template.md` の圧縮優先順位に従う）
- CLAUDE.md では **指示的な言語** を使用する（「Xを使う」「Xしない」）— 記述的ではなく命令的
- CLAUDE.md に **context.md の内容を重複させない**（詳細は context.md に委ねる）
- CLAUDE.md に **信号機システムは使わない**（CLAUDE.md は指示書であり検出結果ではない）
- CLAUDE.md のコマンドは **コピペ可能な正確なコマンド** を記載する
- サブパッケージ CLAUDE.md は **30行以内** に収める（`references/claudemd-template.md` の「30行制限の圧縮ガイド」に従う）
- サブパッケージ CLAUDE.md はルート CLAUDE.md と **内容を重複させない**（共通ルールはルートで定義）
- サブパッケージ CLAUDE.md に **Language セクションは記載しない**（ルートで定義済み）
- `packages/shared/` には CLAUDE.md を **生成しない**（レポートに「手動追加可能」と案内）
- サブパッケージ CLAUDE.md の **Code Style はルートと異なる言語のパッケージにのみ** 記載する
- 質問をスキップして自動選定する場合、次の質問に進む前に自動選定の結果を表示する。形式: 「[項目名] は [選定値] に自動設定されました（理由: [理由]）」
- 同一トリガー（Q1/Q2の回答）に起因する複数のスキップはまとめて通知する。例: GAS選択時は Q2 回答直後（Q4 の前）に「GAS プロジェクトのため、以下が自動設定されました: 言語: TypeScript / ビルド: clasp + esbuild / Linter: Biome / PM: pnpm」と通知する
- 3層/BFFアーキテクチャでモノレポ構成が自動選択される場合も同様に通知する

## 追加リソース

### リファレンスファイル

- **`references/claudemd-template.md`** — CLAUDE.md のテンプレート構造、コマンド導出テーブル、コードスタイルデフォルト、80行制限ガイド
- **`references/tech-recommendations.md`** — 言語×タイプの推奨マトリクス、PM・テスト・Linter推奨表、ディレクトリ構造テンプレート、Docker開発環境推奨表
- **`references/docker-dev-templates.md`** — 言語別docker-compose開発環境テンプレート、DBサービス、Playwright連携
- **`.claude/skills/dev-context/references/context-template.md`** — context.md のテンプレートと記述ガイド（dev-context と共有）
- **`references/ts-scaffolding.md`** — TypeScript スキャフォールディングガイド
- **`references/python-scaffolding.md`** — Python スキャフォールディングガイド
- **`references/rust-scaffolding.md`** — Rust スキャフォールディングガイド
- **`references/go-scaffolding.md`** — Go スキャフォールディングガイド
- **`references/java-scaffolding.md`** — Java スキャフォールディングガイド
- **`references/kotlin-scaffolding.md`** — Kotlin スキャフォールディングガイド
- **`references/dart-scaffolding.md`** — Dart (Flutter) スキャフォールディングガイド
