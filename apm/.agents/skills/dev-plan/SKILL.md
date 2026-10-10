---
name: dev-plan
description: This skill should be used when the user asks to "dev-plan", "実装計画を作成", "要件からタスク分解", "create implementation plan", "plan tasks", "タスクを分割", "設計してタスクにする", "詳細要件定義", "full-spec plan", "EARS要件". ユーザーの要件をインターフェースファースト設計とテスト可能なタスクに分解し、Plan単位でdocs/dev/plans/に保存する。Lightweight（素早い計画）とFull-spec（EARS要件定義付き）の2モードに対応。
argument-hint: '<plan-name> "<requirements>" | <plan-name> <prd-file-path>'
---

# Dev Plan

ユーザーの要件を分析し、インターフェースファーストの設計とテスト可能なタスクに分解する。Plan名で名前空間を分離し、複数要件の並行開発をサポートする。出力は `docs/dev/plans/<plan-name>/` に保存される。

## 前提知識

### dev-*スキルフロー内の位置

```
dev-context → [dev-plan] → dev-impl → dev-verify
```

### 前提条件

- `docs/dev/context.md` が存在すること（dev-contextで生成済み）
- context.md がない場合、先に `/dev-context` の実行を案内する

### 引数フォーマット

```
/dev-plan <plan-name> "<要件の説明>"
/dev-plan <plan-name> <PRDファイルパス>
```

- `plan-name`: 英数字とハイフンのみ（例: `auth`, `payment-integration`, `user-profile`）
  - **日本語が含まれる場合は自動変換する**（Phase 0.5 参照）
- 要件の説明: 自然言語での機能要件
- PRDファイルパス: PRD ドキュメントのファイルパス（`.md` 等）。ファイル内容を要件として読み込む

### 実行モード

| モード | 説明 | 出力 |
|-------|------|------|
| Lightweight | 素早い要件明確化→設計→タスク分解 | plan.md + tasks/ |
| Full-spec | EARS要件定義→ユーザーストーリー→受入基準→設計→タスク分解 | requirements.md + user-stories.md + acceptance-criteria.md + plan.md + tasks/ |

## ワークフロー

### Phase 0: モード選択

AskUserQuestion で実行モードを選択する:

- **Lightweight（推奨: 小さな機能追加・バグ修正）**: 素早く要件を明確化し、設計→タスク分解まで進む
- **Full-spec（推奨: 新規システム・複雑な要件）**: EARS要件定義→ユーザーストーリー→受入基準を作成した上で、設計→タスク分解に進む

選択されたモードに応じて以降の Phase の振る舞いが変わる。

### Phase 0.5: plan-name の正規化

plan-name に日本語（非ASCII文字）が含まれる場合、以下のルールで英数字ケバブケースに自動変換する:

1. 日本語の要件名を簡潔な英語に翻訳する
2. ケバブケース（kebab-case）に変換する
3. 最大50文字程度に収める
4. 変換例:
   - "ユーザー認証システム" → `user-auth-system`
   - "データエクスポート機能" → `data-export`
   - "パスワードリセット" → `password-reset`
   - "お気に入り管理" → `favorite-management`
   - "検索フィルター追加" → `search-filter`
5. 変換後のplan-nameをユーザーに提示し、確認を取ってから続行する

plan-name が既に英数字とハイフンのみの場合はこのフェーズをスキップする。

### Phase 1: 要件明確化

1. **要件入力の判定**: 第2引数がファイルパスかテキストかを判定する
   - ファイルパスの場合（パスに `/` を含む、または `.md` 等の拡張子で終わる）→ Read ツールでファイルを読み込み、内容を要件として使用する
     - PRDファイルが **200行を超える** 場合:
       1. 最初の200行を Read で読み込む
       2. 残りは Explore サブエージェント（`model: haiku`）で要約を取得する
       3. メインコンテキストには **先頭200行 + 要約（50行以内）** のみ保持する
   - ファイルが存在しない場合 → エラーメッセージを表示して終了する
   - テキストの場合 → 従来通りテキストを要件として使用する
2. `docs/dev/context.md` を読み込み、プロジェクトコンテキストを把握する
3. ユーザーの要件（テキストまたはPRDファイル内容）を分析し、不明確な点を特定する
4. AskUserQuestion で曖昧さを段階的に解消する（最大2-3ラウンド）

確認すべき観点:
- 機能のスコープと境界（何をやるか / 何をやらないか）
- ユーザーから見た振る舞い（入力と期待する出力）
- 既存機能への影響範囲
- 非機能要件（パフォーマンス、セキュリティ等）の有無

**Full-spec モードの場合の追加確認**（3-5ラウンド）:
- ペルソナ（誰がどのような目的で使うか）
- パフォーマンス目標値（レスポンスタイム、スループット等の具体的数値）
- セキュリティ要件（認証・認可・データ保護の方針）
- エッジケース（異常系・境界値・競合状態）
- 外部システム連携（API・DB・サードパーティサービス）
- 優先順位（MoSCoW: Must/Should/Could/Won't）

### Phase 1.5: 詳細要件定義（Full-spec のみ）

Full-spec モードの場合のみ実行する。Lightweight の場合はスキップして Phase 2 に進む。

**コンテキスト節約のため、3ドキュメント生成はサブエージェントに委譲する（dev-run パターン）。**

1. `references/fullspec-prompt-template.md` を Read してプロンプトテンプレートを取得する
2. Phase 1 のヒアリング結果を **200行以内** に要約する
3. `docs/dev/context.md` から Tech Stack + Project Structure セクションを **100行以内** に抽出する
4. テンプレートのプレースホルダーを置換する:
   - `{{HEARING_SUMMARY}}` ← ヒアリング結果の要約
   - `{{PLAN_NAME}}` ← Plan名
   - `{{CONTEXT_EXCERPT}}` ← context.md 抜粋
5. general-purpose サブエージェントを起動し、置換済みプロンプトを渡す。サブエージェントが以下の3ドキュメントを一括生成する:
   - `docs/dev/plans/<plan-name>/requirements.md` — EARS形式の機能要件・非機能要件・制約・用語集
   - `docs/dev/plans/<plan-name>/user-stories.md` — ペルソナ・エピック・ストーリー（As a/I want/So that）・MoSCoW優先度・ジャーニー
   - `docs/dev/plans/<plan-name>/acceptance-criteria.md` — Given/When/Then形式の受入基準・テストチェックリスト・横断的基準
6. サブエージェントの結果マーカーを確認する:
   - `FULLSPEC_SUCCESS` → 赤信号リストのみメインコンテキストに取り込む
   - `FULLSPEC_FAILED` → エラー内容を確認し、リトライまたはユーザーに報告する
7. 赤信号（🔴）がある場合は AskUserQuestion でユーザーに確認し、解消してから Phase 2 に進む

### Phase 2: 設計（Architect的役割）

**Full-spec モードの場合**: Plan サブエージェントに Phase 1.5 で生成した3ドキュメントの **ファイルパス** を渡し、サブエージェントが直接 Read で読み込んで設計に反映する。これにより設計がEARS要件に基づいたものになり、かつメインコンテキストで3ドキュメント(~1500行)を保持し続ける必要がなくなる。
   - `docs/dev/plans/<plan-name>/requirements.md`
   - `docs/dev/plans/<plan-name>/user-stories.md`
   - `docs/dev/plans/<plan-name>/acceptance-criteria.md`

Plan サブエージェント（`subagent_type: Plan`）で関連コードベースを分析する:

1. **既存コードの調査**: 関連する既存実装、インターフェース、型定義を探索
2. **インターフェースファースト設計**:
   - 実装詳細より先に型/インターフェースを定義する
   - これが後続の dev-impl で「幻覚」を防ぐ契約書として機能する
   - dev-impl は context.md + インターフェース定義だけで実装可能にする
3. **データフロー整理**: 入力→処理→出力の流れを整理する
4. **依存関係の特定**: 既存コードとの接続点、新規モジュール間の依存を明確にする

### Phase 3: タスク分解

テスト可能な単位にタスクを分割する:

1. **タスクの粒度**: 1タスク = 1つのテスト可能な振る舞い単位
2. **依存関係グラフ**: タスク間の実装順序を決定する
3. **複雑度見積もり**: 各タスクを low / medium / high に分類
4. **テスト方針**: 各タスクに「何をテストするか」を明記する
5. **ファイル影響範囲**: 各タスクが影響するファイルパスを列挙する

### Phase 4: ファイル出力

以下のディレクトリとファイルを生成する:

```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
mkdir -p "$PROJECT_ROOT/docs/dev/plans/<plan-name>/tasks"
mkdir -p "$PROJECT_ROOT/docs/dev/plans/<plan-name>/reports"
```

#### 出力ディレクトリ構成

**Lightweight モード**:
```
docs/dev/plans/<plan-name>/
├── plan.md
├── tasks/
│   └── NNN-task-name.md
└── reports/
```

**Full-spec モード**:
```
docs/dev/plans/<plan-name>/
├── plan.md                    # 要件概要・設計メモ・タスク依存グラフ
├── requirements.md            # EARS要件定義（Phase 1.5で生成済み）
├── user-stories.md            # ユーザーストーリー（Phase 1.5で生成済み）
├── acceptance-criteria.md     # 受入基準（Phase 1.5で生成済み）
├── tasks/
│   └── NNN-task-name.md
└── reports/
```

#### plan.md の生成

`docs/dev/plans/<plan-name>/plan.md` に要件概要と設計メモを記録:

```markdown
# Plan: <plan-name>
## Requirements Summary
[要件の要約]
<!-- Full-spec モードの場合、以下のリンクを追加 -->
<!-- 詳細: [requirements.md](requirements.md) | [user-stories.md](user-stories.md) | [acceptance-criteria.md](acceptance-criteria.md) -->
## Design Overview
[インターフェース設計の概要]
## Task Dependency Graph
[タスク間の依存関係]
## Cross-Plan Dependencies
[他のPlanとの共有インターフェースがある場合に記載]
```

Full-spec モードの場合、Requirements Summary に要件ドキュメントへの相対リンクを記載する。

#### タスクファイルの生成

各タスクを `docs/dev/plans/<plan-name>/tasks/NNN-task-name.md` に出力する。`references/task-template.md` のテンプレートに従う。

## 信号機システム

設計の各要素に確信度を付与する:

- 🔵 **前工程指示**: 既存コードのパターンに完全に沿った設計、明示的な仕様に基づく
- 🟡 **妥当な推測**: ベストプラクティスに基づくが、プロジェクトでの明示的な前例がない
- 🔴 **AI推論補完**: アーキテクチャ判断が必要、組織固有のポリシーに依存する箇所

インターフェース定義の各メソッド/プロパティに確信度を付与し、タスクファイルに記録する。🔴 がある場合はユーザーに AskUserQuestion で確認する。

## ルール・制約

- context.md が存在しない場合、先に `/dev-context` の実行を案内して終了する
- 既存の `docs/dev/plans/<plan-name>/` が存在する場合、上書きするか確認する
- タスクファイルは 001 から連番で命名する
- 1タスクの見積もり粒度: dev-impl 1回で完了する単位
- インターフェース定義は可能な限り具体的に（`any` や `unknown` を避ける）
- テスト方針は具体的な振る舞いで記述する（「正しく動作する」のような曖昧表現を避ける）
- 各タスクファイルは500行以内
- サブエージェントによる探索結果は要約のみメインコンテキストに返す
- Bash コマンドはプロジェクトルートの **絶対パス** を使用する（`$(git rev-parse --show-toplevel)` でルートを取得）

## 追加リソース

### リファレンスファイル

- **`references/task-template.md`** — タスクファイルのテンプレートとフロントマター仕様
- **`references/fullspec-templates.md`** — Full-spec モード用の要件ドキュメントテンプレート（requirements.md, user-stories.md, acceptance-criteria.md）と EARS 記述ガイド
- **`references/fullspec-prompt-template.md`** — Full-spec モード Phase 1.5 のサブエージェント用プロンプトテンプレート（`{{HEARING_SUMMARY}}`, `{{PLAN_NAME}}`, `{{CONTEXT_EXCERPT}}` を置換して使用）
