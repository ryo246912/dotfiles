---
name: dev-run
description: This skill should be used when the user asks to "dev-run", "自動実装", "タスクを一括実装", "auto implement", "run all tasks", "タスクを自動実行", "バッチ実装", "dev-run auth 001 005". Plan内の指定範囲のタスクをdev-impl/dev-verify/dev-debugのワークフローで自動実行するオーケストレーションスキル。
argument-hint: '<plan-name> <from-task-id> <to-task-id>'
---

# Dev Run

Plan 内の指定範囲タスクに対し、impl → verify → debug のループを自動実行するオーケストレーションスキル。各タスクを Task サブエージェントに委託し、TaskCreate/TaskUpdate で依存関係付きの進捗管理を行う。

## 前提知識

### dev-* スキルフロー内の位置

```
dev-context → dev-plan → [dev-run] → (完了)
                            ├─ impl サブエージェント (×タスク数)
                            ├─ debug サブエージェント (エラー時)
                            └─ verify サブエージェント (全タスク完了後)
```

### 引数フォーマット

```
/dev-run <plan-name> <from-task-id> <to-task-id>
```

- `plan-name`: 既存の Plan 名（`docs/dev/plans/<plan-name>/` が存在すること）
- `from-task-id`: 開始タスク ID（例: "001"）
- `to-task-id`: 終了タスク ID（例: "005"）

### サブエージェント制約（重要）

サブエージェントは Task ツールを使用できない（ネスト不可のアーキテクチャ制約）。そのため:
- コード探索は Glob/Grep/Read を直接使用する
- TodoWrite は使用しない（TaskCreate/TaskUpdate で進捗管理する）
- プロンプトに context.md を埋め込み、サブエージェントのファイル読み込みを最小化する

## ワークフロー

### Step 1: 事前検証とコンテキスト読み込み

1. `docs/dev/context.md` の存在を確認する。存在しない場合は `/dev-context` の実行を案内して終了する
2. `docs/dev/plans/<plan-name>/` の存在を確認する。存在しない場合は `/dev-plan` の実行を案内して終了する
3. `docs/dev/context.md` を Read で読み込み、以下を抽出する:
   - テスト実行コマンド（Test Framework セクション）
   - ビルドコマンド（Build & Run セクション、あれば）
   - Lint コマンド（Build & Run セクション、あれば）
   - カバレッジ閾値（Test Framework セクションの Coverage Threshold）
4. `docs/dev/plans/<plan-name>/plan.md` を Read で読み込む
5. 指定範囲（from-task-id 〜 to-task-id）の全タスクファイルを Glob + Read で読み込む
6. 各タスクの `status`, `dependencies`, `estimated_complexity` を確認する

#### 範囲外依存チェック

タスクファイルの `dependencies` に、指定範囲外のタスク ID が含まれる場合:
- そのタスクファイルを Read し、`status` を確認する
- `status: done` → 問題なし
- それ以外 → AskUserQuestion でユーザーに警告し、続行/中断を確認する

### Step 2: TaskCreate で依存関係グラフ構築

#### 2a. タスクの登録

指定範囲内で `status` が `done` でないタスクごとに TaskCreate を実行する:

```
TaskCreate:
  subject: "impl-NNN: <タスクタイトル>"
  description: "Plan <plan-name> のタスク NNN を TDD 実装する"
  activeForm: "Implementing task NNN: <タスクタイトル>"
```

#### 2b. 依存関係の設定

タスクファイルの `dependencies` を TaskUpdate の `addBlockedBy` にマッピングする。

ID マッピングテーブルを構築: `{"001": "<TaskCreate_ID>", "002": "<TaskCreate_ID>", ...}`

- 範囲内の依存: 対応する TaskCreate ID を blockedBy に設定
- 範囲外の依存（done 済み）: blockedBy から除外
- `status: done` のタスク: TaskCreate しない、依存元からも除外

#### 2c. verify タスクの登録

```
TaskCreate:
  subject: "verify: <plan-name>"
  description: "Plan <plan-name> の全体検証を実行する"
  activeForm: "Verifying plan <plan-name>"
  addBlockedBy: [全 impl タスクの ID]
```

### Step 3: 実装ループ

TaskList で `status: pending` かつ `blockedBy` が空のタスクを取得し、順に実行する。

#### 3a. impl タスクの実行

1. TaskUpdate で `in_progress` にする
2. `references/impl-prompt-template.md` を Read で読み込む
3. テンプレートのプレースホルダーを置換する:
   - `{{CONTEXT_MD_CONTENT}}` ← context.md の全文
   - `{{TASK_FILE_CONTENT}}` ← タスクファイルの全文
   - `{{PLAN_MD_EXCERPT}}` ← plan.md の設計概要
   - `{{TEST_COMMAND}}` ← テスト実行コマンド
   - `{{TASK_FILE_PATH}}` ← タスクファイルのパス
   - `{{ESTIMATED_COMPLEXITY}}` ← タスクの複雑度
   - `{{COVERAGE_THRESHOLD}}` ← カバレッジ閾値
4. Task サブエージェント（general-purpose）を起動する
5. サブエージェントの出力を確認する:
   - `IMPL_SUCCESS` を含む → 成功処理（3c へ）
   - `IMPL_FAILED` を含む → debug 処理（3b へ）

#### 3b. debug 処理（impl 失敗時）

1. impl サブエージェントの出力からエラー情報を抽出する
2. `references/debug-prompt-template.md` を Read で読み込む
3. テンプレートのプレースホルダーを置換する:
   - `{{CONTEXT_MD_CONTENT}}` ← context.md の全文
   - `{{ERROR_DETAILS}}` ← エラー情報（impl の出力から抽出）
   - `{{TASK_FILE_CONTENT}}` ← タスクファイルの全文
   - `{{TEST_COMMAND}}` ← テスト実行コマンド
4. Task サブエージェント（general-purpose）を起動する
5. サブエージェントの出力を確認する:
   - `DEBUG_SUCCESS` → 成功処理（3c へ）
   - `DEBUG_FAILED` → エスカレーション:
     AskUserQuestion で以下を提示:
     - このタスクをスキップして次へ進む
     - 自動実行を中断する
     - 手動修正後に再開する

#### 3c. 成功処理

1. タスクファイルの frontmatter `status` を `done` に更新する（Edit ツール使用）
   - **注意**: dev-run の allowed-tools に Edit は含まれないため、ここはサブエージェント内で実施済みのはず。サブエージェントが更新していない場合は Read で確認する
2. TaskUpdate で `completed` にする
3. TaskList で次のブロック解除タスクを確認する
4. 次のタスクがあれば 3a に戻る

### Step 4: 全体検証（verify タスク実行）

全 impl タスクが completed になると verify タスクのブロックが解除される。

1. TaskUpdate で verify を `in_progress` にする
2. `references/verify-prompt-template.md` を Read で読み込む
3. テンプレートのプレースホルダーを置換する:
   - `{{CONTEXT_MD_CONTENT}}` ← context.md の全文
   - `{{PLAN_NAME}}` ← Plan 名
   - `{{TEST_COMMAND}}`, `{{BUILD_COMMAND}}`, `{{LINT_COMMAND}}`
   - `{{COVERAGE_THRESHOLD}}` ← カバレッジ閾値
   - `{{TODAY_DATE}}` ← 実行日（YYYY-MM-DD）
4. Task サブエージェント（general-purpose）を起動する
5. サブエージェントが検証レポートを `docs/dev/plans/<plan-name>/reports/verify-<日付>.md` に出力する

### Step 5: 検証結果パースと修正ループ

verify サブエージェント完了後:

1. 出力マーカーを確認する:
   - `VERIFY_ALL_PASSED` → 全パス、Step 6 へ
   - `VERIFY_ISSUES_FOUND` → 修正ループへ

#### 修正ループ（最大2サイクル）

サイクルごとに:

1. レポートファイルを Read で読み込む
2. Issues Found セクションから問題を抽出する
3. 問題ごとに fix タスクを TaskCreate する:
   ```
   subject: "fix-NNN: <問題概要>"
   activeForm: "Fixing: <問題概要>"
   addBlockedBy: [verify タスクの ID]
   ```
4. re-verify タスクを TaskCreate する:
   ```
   subject: "re-verify-N: <plan-name>"
   activeForm: "Re-verifying plan <plan-name>"
   addBlockedBy: [全 fix タスクの ID]
   ```
5. fix タスクを実行する（debug サブエージェント使用、3b と同じフロー）
6. re-verify タスクを実行する（verify サブエージェント使用、Step 4 と同じフロー）
7. 結果を確認:
   - 全パス → Step 6 へ
   - まだ問題あり:
     - サイクル 1 → サイクル 2 へ
     - サイクル 2 → 残存問題を報告して Step 6 へ

### Step 6: 最終レポート

ユーザーに以下を出力する:

```markdown
## dev-run 完了レポート

### 実行概要
- Plan: <plan-name>
- 範囲: <from-task-id> 〜 <to-task-id>
- 実行タスク数: X / スキップ: Y (done 済み)

### 結果サマリー
| タスク | 結果 | 信号機 |
|-------|------|--------|
| NNN | 成功 / debug後成功 / スキップ | 🔵/🟡/🔴 |

### 検証結果
- テスト: X passed, Y failed
- カバレッジ: X/Y packages above threshold
- ビルド: OK / NG / N/A
- Lint: OK / NG / N/A
- 500行ルール: OK / X files over

### verify → fix サイクル
- サイクル N: [修正内容の概要]

### 残存問題（ある場合）
- [問題の詳細と推奨アクション]

### 🟡 要確認ファイル
- [ファイル一覧と確認ポイント]

### 🔴 要判断ファイル
- [ファイル一覧と判断が必要な理由]
```

### Step 7: Docker クリーンアップ

プロジェクトルートに `docker-compose.yml` または `docker-compose.yaml` が存在するか確認する。存在する場合:

1. `docker compose down` を実行してコンテナを停止する
2. 停止に失敗した場合はユーザーに報告する（ブロッキングにしない）

## エスカレーション条件

以下の場合は自動実行を停止し、AskUserQuestion でユーザーに確認する:

1. **範囲外依存が未完了**: 依存先タスクが done でない
2. **impl + debug 両方失敗**: サブエージェントが修正できなかった
3. **verify 2サイクル後も問題残存**: 残存問題をレポートして終了
4. **🔴 セキュリティ/パフォーマンス問題**: レポートに明記、人間レビュー推奨
5. **context.md / plan が存在しない**: 前提スキルの実行を案内して終了

## マーカー文字列

| マーカー | 意味 |
|---------|------|
| `IMPL_SUCCESS` | 実装成功（テスト全通過） |
| `IMPL_FAILED` | 実装失敗（3サイクル超え） |
| `DEBUG_SUCCESS` | デバッグ成功（エラー解消） |
| `DEBUG_FAILED` | デバッグ失敗（3サイクル超え） |
| `VERIFY_ALL_PASSED` | 検証全項目 OK |
| `VERIFY_ISSUES_FOUND` | 検証で問題あり |

## ルール・制約

- context.md が存在しない場合は `/dev-context` を案内して終了する
- plan が存在しない場合は `/dev-plan` を案内して終了する
- `status: done` のタスクはスキップする（再開対応）
- verify → fix → re-verify のサイクルは最大2回
- サブエージェントには Task ツールを使用させない（プロンプトで明示）
- 各プロンプトに context.md を埋め込みサブエージェントの Read 回数を最小化する
- テスト/ビルド/Lint コマンドは context.md から取得する（ハードコードしない）
- すべてのファイルは 500 行以内
- Bash コマンドはプロジェクトルートの **絶対パス** を使用する（`$(git rev-parse --show-toplevel)` でルートを取得）

## 追加リソース

### リファレンスファイル

- **`references/impl-prompt-template.md`** — impl サブエージェントに渡すプロンプトテンプレート
- **`references/debug-prompt-template.md`** — debug サブエージェントに渡すプロンプトテンプレート
- **`references/verify-prompt-template.md`** — verify サブエージェントに渡すプロンプトテンプレート
