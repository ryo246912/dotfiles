---
name: dev-webtest-plan
description: This skill should be used when the user asks to "dev-webtest-plan", "Webテスト計画を生成", "テスト計画を作成", "webtest plan", "E2Eテスト計画", "画面テスト計画", "generate webtest plan", "create test plan from requirements", "webtest計画を更新", "テスト計画の差分更新", "update webtest plan", "画面仕様からテスト更新". dev-planの出力からPlaywright用のWebテスト計画ファイルを自動生成する。画面仕様の変更差分からテスト計画を更新する差分更新モードも対応。
argument-hint: '<dev-plan-name> | update [plan-name]'
---

# Dev Webtest Plan

dev-plan の出力（acceptance-criteria.md の Given/When/Then、タスクファイルの Test Strategy 等）から、dev-webtest が実行する Playwright 用 Web テスト計画ファイルを自動生成するスキル。画面仕様ドキュメント（Screen Spec）の変更差分から既存テスト計画を更新する差分更新モードも備える。

## 前提知識

### dev-* スキルフロー内の位置

```
dev-context → dev-plan → [dev-webtest-plan] → dev-impl → dev-verify → dev-webtest
                              ↓                                           ↑
                    docs/dev/webtests/plans/*.md ─────────────────────────┘

dev-screen-spec → [dev-webtest-plan update] → dev-webtest
                        ↓ (差分更新)              ↑
              docs/dev/webtests/plans/*.md ───────┘
```

### 引数フォーマット

```
/dev-webtest-plan <dev-plan-name>          # 新規生成モード
/dev-webtest-plan update                   # 差分更新モード（全webtest計画対象）
/dev-webtest-plan update <plan-name>       # 差分更新モード（特定webtest計画のみ）
```

- `dev-plan-name`: 既存の Plan 名（`docs/dev/plans/<dev-plan-name>/` が存在すること）
- `update`: 差分更新モードのキーワード
- `plan-name`: 更新対象のwebtest計画名（省略時は全計画を対象）

### モード自動判定

引数で自動判定する（ユーザー質問不要）:

```
引数が "update" で始まる → 差分更新モード
それ以外 → 新規生成モード（現行通り）
```

#### 新規生成モードのサブ判定

acceptance-criteria.md の存在で自動判定する:

| モード | 判定条件 | 特徴 |
|-------|---------|------|
| Full-spec | `docs/dev/plans/<name>/acceptance-criteria.md` が存在 | AC の Given/When/Then から直接変換（🔵 多い） |
| Lightweight | acceptance-criteria.md が存在しない | タスクの Test Strategy から推論（🟡 主体、🔵 なし） |

#### 差分更新モード

| モード | 判定条件 | 特徴 |
|-------|---------|------|
| 差分更新 | 引数が `update` で始まる | 画面仕様の変更差分からテスト計画を更新（🟡 source: screen-spec update） |

### サブエージェント制約（重要）

サブエージェントは Task ツールを使用できない（ネスト不可のアーキテクチャ制約）。そのため:
- コード探索は Glob/Grep/Read を直接使用する
- TodoWrite は使用しない（TaskCreate/TaskUpdate で進捗管理する）
- サブエージェントに渡すのはファイルパスのみ。サブエージェントが自分で Read する

### コンテキスト管理戦略

メインコンテキストの肥大化を防ぐため、**中間ファイルとパス参照** を使用する:
- メインエージェントはファイルの全文を Read しない（パス存在確認・Grep での部分情報取得のみ）
- サブエージェントに渡すのはファイルパス。サブエージェントが自分で Read する
- Phase 間のデータ受け渡しは中間ファイル経由（`tmp/webtest/plan/<plan-name>/`）
- サブエージェントの返却はマーカー＋ファイルパス＋行数のみ

### 中間ファイル（新規生成モード）

```
tmp/webtest/plan/<plan-name>/
├── task-summary.md          # Phase 2a で生成（タスクサマリー）
├── explore-plan-result.md   # Phase 2a の出力（Plan 分析結果）
├── explore-code-result.md   # Phase 2b の出力（UI 要素情報）
└── design-result.md         # Phase 3 の出力（構造設計結果）
```

### 中間ファイル（差分更新モード）

```
tmp/webtest/update/
└── analyze-<plan-name>.md   # Phase 2 の出力（変更分析結果）
```

## ワークフロー（新規生成モード）

> 以下は引数が `update` で始まらない場合のワークフロー。

### Phase 1: コンテキスト確認と入力検証（メイン）

1. `docs/dev/context.md` の存在を確認する。存在しない場合は `/dev-context` の実行を案内して終了する
2. `docs/dev/plans/<dev-plan-name>/` の存在を確認する。存在しない場合は `/dev-plan` の実行を案内して終了する
3. **モード自動判定**: `docs/dev/plans/<dev-plan-name>/acceptance-criteria.md` の存在を確認する
   - 存在する → **Full-spec モード**
   - 存在しない → **Lightweight モード**
4. Full-spec 時: `acceptance-criteria.md`, `user-stories.md`, `requirements.md` のパスを記録する（Read はしない）
5. `docs/dev/plans/<dev-plan-name>/tasks/` 配下のタスクファイルパス一覧を Glob で取得する（Read はしない）
6. Grep で `status: done` のタスクがあるか確認する（Phase 2b 実行判定用）
7. タスクの Files セクションに記載されたファイルが実際に存在するか Grep + Glob で確認する（Phase 2b 実行判定用）
8. 既存 webtest plan との重複確認:
   - `docs/dev/webtests/plans/` 配下を Glob で確認
   - 同一 `source-plan` の webtest plan が存在する場合は AskUserQuestion で上書き確認する
9. 中間ファイルディレクトリを作成する: `mkdir -p tmp/webtest/plan/<plan-name>/`

### Phase 2: 画面・フロー・API分析（Explore サブエージェント x2 並列）

**2a. dev-plan 分析**（Explore, haiku）と **2b. 実装コード探索**（Explore, haiku、オプション）を並列で実行する。API セットアップ/クリーンアップに必要なエンドポイント情報も同時に収集する。

#### 2a. dev-plan 分析

1. `references/explore-plan-prompt-template.md` を Read で読み込む
2. テンプレートのプレースホルダーを置換する:
   - `{{PLAN_MD_PATH}}` ← plan.md の絶対パス
   - `{{ACCEPTANCE_CRITERIA_PATH}}` ← acceptance-criteria.md の絶対パス（Lightweight 時は「なし」）
   - `{{TASK_FILE_PATHS}}` ← 全タスクファイルの絶対パス一覧（1行1パス）
   - `{{MODE}}` ← "Full-spec" または "Lightweight"
   - `{{TMP_DIR}}` ← `tmp/webtest/plan/<plan-name>/` の絶対パス
3. Explore サブエージェント（haiku）を起動する
4. 出力のマーカーを確認する:
   - `EXPLORE_PLAN_SUCCESS` → Phase 3 へ進む
   - `EXPLORE_PLAN_FAILED` → エラー理由をユーザーに報告して終了

#### 2b. 実装コード探索（オプション）

以下のいずれかの条件を満たす場合のみ実行する:
- タスクファイルに `status: done` が1つ以上存在する
- タスクの Files セクションに記載されたファイルが実際に存在する（Glob で確認）

条件を満たさない場合はスキップし、Phase 3 で `draft: true` として設計する。

**追加探索**: API セットアップ/クリーンアップ用のエンドポイント情報も収集する:
- API仕様ファイルの自動探索（openapi.yaml, swagger.json 等）
- ルーティング定義からのCRUD APIエンドポイント抽出
- 認証フローの調査（ログインAPI、トークン取得方法）

1. `references/explore-code-prompt-template.md` を Read で読み込む
2. テンプレートのプレースホルダーを置換する:
   - `{{CONTEXT_MD_PATH}}` ← context.md の絶対パス
   - `{{TARGET_FILES}}` ← タスクの Files セクションから抽出したファイルパス一覧
   - `{{TMP_DIR}}` ← `tmp/webtest/plan/<plan-name>/` の絶対パス
3. Explore サブエージェント（haiku）を起動する
4. 出力のマーカーを確認する:
   - `EXPLORE_CODE_SUCCESS` → Phase 3 へ進む
   - `EXPLORE_CODE_FAILED` → スキップ、`draft: true` で進行

### Phase 3: webtest plan 構造設計（Plan サブエージェント）

API セットアップ/クリーンアップの設計も含む。Phase 2 の分析結果からAPIエンドポイント情報を活用し、各 webtest plan に実行可能な curl コマンドを設計する。

1. `references/design-prompt-template.md` を Read で読み込む
2. テンプレートのプレースホルダーを置換する:
   - `{{MODE}}` ← "Full-spec" または "Lightweight"
   - `{{EXPLORE_PLAN_RESULT_PATH}}` ← `tmp/webtest/plan/<plan-name>/explore-plan-result.md` の絶対パス
   - `{{EXPLORE_CODE_RESULT_PATH}}` ← `tmp/webtest/plan/<plan-name>/explore-code-result.md` の絶対パス（スキップ時は「なし」）
   - `{{TASK_SUMMARY_PATH}}` ← `tmp/webtest/plan/<plan-name>/task-summary.md` の絶対パス
   - `{{WEBTEST_PLAN_FORMAT_PATH}}` ← `references/webtest-plan-format.md` の絶対パス
   - `{{TMP_DIR}}` ← `tmp/webtest/plan/<plan-name>/` の絶対パス
3. Plan サブエージェントを起動する
4. 出力のマーカーを確認する:
   - `DESIGN_SUCCESS` → Phase 4 へ進む
   - `DESIGN_FAILED` → エラー理由をユーザーに報告して終了

### Phase 4: TaskCreate で並列生成タスク登録（メイン）

Phase 3 の中間ファイル `tmp/webtest/plan/<plan-name>/design-result.md` を Read し、webtest plan の一覧を抽出する。各 webtest plan ごとに TaskCreate を実行する:

```
TaskCreate:
  subject: "webtest-plan: <webtest-plan-name>"
  description: "<webtest-plan-name> の webtest plan ファイルを生成する"
  activeForm: "Generating webtest-plan: <webtest-plan-name>"
```

ID マッピングテーブルを構築する: `{"login-form": "<TaskCreate_ID>", ...}`

通常は依存関係なし（並列生成可能）。

### Phase 5: webtest plan ファイル生成（general-purpose サブエージェント x N）

TaskList で `status: pending` のタスクを取得し、各タスクについて:

1. TaskUpdate で `in_progress` にする
2. `references/generate-prompt-template.md` を Read で読み込む
3. テンプレートのプレースホルダーを置換する:
   - `{{WEBTEST_PLAN_NAME}}` ← webtest plan 名
   - `{{TARGET_URL}}` ← target-url
   - `{{DRAFT_FLAG}}` ← true / false
   - `{{MODE}}` ← "Full-spec" または "Lightweight"
   - `{{DESIGN_RESULT_PATH}}` ← `tmp/webtest/plan/<plan-name>/design-result.md` の絶対パス
   - `{{TASK_SUMMARY_PATH}}` ← `tmp/webtest/plan/<plan-name>/task-summary.md` の絶対パス
   - `{{EXPLORE_CODE_RESULT_PATH}}` ← `tmp/webtest/plan/<plan-name>/explore-code-result.md` の絶対パス（ない場合は「なし」）
   - `{{WEBTEST_PLAN_FORMAT_PATH}}` ← `references/webtest-plan-format.md` の絶対パス
   - `{{SIGNAL_GUIDELINES}}` ← 信号機基準（Full-spec / Lightweight で異なる）
   - `{{ACCEPTANCE_CRITERIA_PATH}}` ← acceptance-criteria.md の絶対パス（Full-spec 時のみ、Lightweight 時は「なし」）
4. general-purpose サブエージェントを起動する
5. 出力のマーカーを確認する:
   - `GENERATE_SUCCESS` → TaskUpdate で `completed` にする
   - `GENERATE_FAILED` → エラー理由を記録、TaskUpdate で `completed`（レポートに失敗として記載）
6. 複数の webtest plan がある場合は並列で実行する（Agent ツールを複数同時起動）

### Phase 6: 完了レポートと次ステップ案内（メイン）

ユーザーに以下のレポートを出力する:

```markdown
## dev-webtest-plan 完了レポート

### 生成概要
- Source Plan: <dev-plan-name>
- モード: Full-spec / Lightweight
- 生成ファイル数: N

### 生成ファイル一覧

| ファイル | target-url | draft | シナリオ数 | 🔵 | 🟡 | 🔴 | APIセットアップ |
|---------|-----------|-------|----------|-----|-----|-----|--------------|
| login-form.md | http://app:8080/login | false | 5 | 3 | 1 | 1 | あり（共通1, 固有0） |
| dashboard.md | http://app:8080/dashboard | true | 3 | 0 | 2 | 1 | あり（共通1, 固有2） |

### 対象外タスク
- task-NNN: <理由（API のみ、バッチ処理等）>

### ⚠️ 🔴 警告
以下のシナリオは前工程に根拠がなく、AI が推論で追加しました。内容を確認してください:
- <ファイル名> シナリオN: <シナリオ名>

### 📋 draft ファイルの補完方法
draft: true のファイルは UI 要素名が推定です。
dev-impl 完了後に `/dev-webtest-plan <dev-plan-name>` を再実行すると、
実装コードから UI 要素を確認し draft: false に更新できます。

### 🚀 次のステップ
- 実装前の場合: `/dev-impl <dev-plan-name>` で実装を進める
- 実装後の場合: `/dev-webtest <webtest-plan-name>` でテストを実行する
```

レポート出力後、中間ファイルをクリーンアップする:
```bash
rm -rf tmp/webtest/plan/<plan-name>/
```

## 信号機基準（新規生成モード）

| 信号 | 基準 |
|------|------|
| 🔵 | AC の Given/When/Then から直接変換、requirements.md の明示的要件に基づく |
| 🟡 | タスクの Test Strategy から推論、一般的 Web テストベストプラクティス |
| 🔴 | 前工程に根拠なし、AI が Web テストとして必要と判断した項目 |

## サブエージェント戦略（新規生成モード）

| Phase | タイプ | モデル | 用途 | 並列 |
|-------|-------|--------|------|------|
| 2a | Explore | haiku | dev-plan分析・画面分割判定 | 2bと並列 |
| 2b | Explore | haiku | 実装コード探索（オプション） | 2aと並列 |
| 3 | Plan | (default) | webtest plan構造設計 | 単独 |
| 5 | general-purpose | (default) | ファイル生成 | plan数分並列 |

## エスカレーション条件（新規生成モード）

以下の場合は自動処理を停止し、ユーザーに確認する:

1. **context.md 不在**: `/dev-context` を案内して終了
2. **plan 不在**: `/dev-plan` を案内して終了
3. **既存 webtest plan との重複**: AskUserQuestion で上書き確認
4. **Phase 2a 失敗**: plan.md の情報不足を報告して終了
5. **Phase 3 失敗**: 設計不能の理由を報告して終了

## マーカー文字列（新規生成モード）

| マーカー | 意味 |
|---------|------|
| `EXPLORE_PLAN_SUCCESS` | dev-plan 分析成功 |
| `EXPLORE_PLAN_FAILED` | dev-plan 分析失敗 |
| `EXPLORE_CODE_SUCCESS` | 実装コード探索成功 |
| `EXPLORE_CODE_FAILED` | 実装コード探索失敗 |
| `DESIGN_SUCCESS` | 構造設計成功 |
| `DESIGN_FAILED` | 構造設計失敗 |
| `GENERATE_SUCCESS` | ファイル生成成功 |
| `GENERATE_FAILED` | ファイル生成失敗 |

---

## ワークフロー（差分更新モード）

> 以下は引数が `update` で始まる場合のワークフロー。新規生成モードとは完全に独立。

### Phase 1: 入力検証と変更検知（メイン）

1. `docs/dev/context.md` の存在を確認する。存在しない場合は `/dev-context` の実行を案内して終了する
2. `docs/dev/screen-specs/_index.md` の存在を確認する
   - 存在しない場合は `/dev-screen-spec` の実行を案内して終了する
3. `docs/dev/webtests/plans/` 配下の既存テスト計画一覧を取得する
   - 引数に `plan-name` が指定されている場合はそのファイルのみ対象
   - テスト計画が存在しない場合は「更新対象のテスト計画がありません」と報告して終了する
4. 画面仕様ドキュメントの変更を検知する:
   - 各テスト計画の frontmatter から `last-run` 日付を取得する
   - 各画面仕様の frontmatter から `updated_at` を取得する
   - `updated_at` > `last-run` の画面仕様 → 変更ありと判定する
   - **代替手段**: 画面仕様ファイルの `last_synced_commit` とテスト計画の `screen_spec_commit` フィールドを比較する
5. 変更のある画面仕様を特定し、影響するテスト計画をマッピングする:
   - 画面仕様の `screen_id` / `path` とテスト計画の `target-url` を突き合わせる
   - テスト計画のシナリオ内のURLパスとも照合する
6. 影響なしの場合 → 「変更なし」を表示して終了する
7. 影響のあるテスト計画と変更画面の対応表を表示する
8. 中間ファイルディレクトリを作成する: `mkdir -p tmp/webtest/update/`

### Phase 2: 変更差分の分析（並列 Explore サブエージェント）

影響のあるテスト計画ごとに Explore サブエージェントを起動する（並列）:

1. `references/update-analyze-prompt-template.md` を Read で読み込む
2. テンプレートのプレースホルダーを置換する:
   - `{{WEBTEST_PLAN_PATH}}` ← 既存テスト計画ファイルの絶対パス
   - `{{CHANGED_SCREEN_SPEC_PATHS}}` ← 変更のあった画面仕様ファイルの絶対パス一覧
   - `{{SCREEN_SPEC_INDEX_PATH}}` ← `docs/dev/screen-specs/_index.md` の絶対パス
   - `{{TMP_DIR}}` ← `tmp/webtest/update/` の絶対パス
3. Explore サブエージェント（haiku）を起動する
4. 出力のマーカーを確認する:
   - `UPDATE_ANALYZE_SUCCESS` → Phase 3 へ進む
   - `UPDATE_ANALYZE_FAILED` → エラー理由をユーザーに報告して終了する

### Phase 3: テスト計画の更新適用（並列 general-purpose サブエージェント）

テスト計画ごとに general-purpose サブエージェントを起動する（並列）:

1. `references/update-apply-prompt-template.md` を Read で読み込む
2. テンプレートのプレースホルダーを置換する:
   - `{{WEBTEST_PLAN_PATH}}` ← 既存テスト計画ファイルの絶対パス
   - `{{ANALYZE_RESULT_PATH}}` ← `tmp/webtest/update/analyze-<plan-name>.md` の絶対パス
   - `{{CHANGED_SCREEN_SPEC_PATHS}}` ← 変更のあった画面仕様ファイルの絶対パス一覧
   - `{{WEBTEST_PLAN_FORMAT_PATH}}` ← `references/webtest-plan-format.md` の絶対パス
3. general-purpose サブエージェントを起動する
4. 出力のマーカーを確認する:
   - `UPDATE_APPLY_SUCCESS` → Phase 4 へ進む
   - `UPDATE_APPLY_FAILED` → エラー理由を記録、レポートに失敗として記載する

### Phase 4: 完了レポートと後処理（メイン）

ユーザーに以下のレポートを出力する:

```markdown
## dev-webtest-plan 差分更新レポート

### 変更元
- 画面仕様の変更: N 画面

### 更新されたテスト計画

| テスト計画 | 追加 | 修正 | 削除 | 合計シナリオ |
|-----------|------|------|------|------------|
| login-form.md | +2 | ~1 | -0 | 7 |
| dashboard.md | +0 | ~3 | -1 | 5 |

### 変更詳細

#### login-form.md
- ✅ 追加: シナリオ「電話番号バリデーション」（画面仕様: login.md のバリデーション追加に対応）
- ✅ 追加: シナリオ「2要素認証フロー」（画面仕様: login.md のインタラクション追加に対応）
- ✏️ 修正: シナリオ「パスワードバリデーション」（ルール変更: 8文字→10文字）

### 🚀 次のステップ
- `/dev-webtest <plan-name>` でテストを実行する
```

レポート出力後、中間ファイルをクリーンアップする:
```bash
rm -rf tmp/webtest/update/
```

## webtest計画 frontmatter への追加フィールド（差分更新用）

差分更新の追跡のため、既存のfrontmatterに以下を追加する:

```yaml
---
# ... 既存フィールド ...
screen_spec_commit: abc1234    # この計画が参照した画面仕様の last_synced_commit
last_updated: "2026-03-09"     # 差分更新の最終日
update_history:                # 更新履歴（直近3回）
  - date: "2026-03-09"
    changes: "+2 ~1 -0"
    source: "screen-spec update"
---
```

- `screen_spec_commit`: 新規生成時にも画面仕様が存在する場合は設定する
- `last_updated`: 差分更新を実行した日付
- `update_history`: 直近3回の更新履歴。古いものから削除する

## 画面仕様 → テスト計画のセクション対応マッピング

| 画面仕様セクション | テスト計画の更新対象 |
|------------------|-------------------|
| 画面項目（追加） | 新規シナリオ追加（要素の表示確認） |
| 画面項目（変更） | 既存シナリオの手順・期待結果を修正 |
| 画面項目（削除） | 該当シナリオを削除 |
| バリデーション（追加） | フォームバリデーション確認テーブルに行追加 + シナリオ追加 |
| バリデーション（変更） | フォームバリデーション確認テーブル更新 + シナリオ修正 |
| バリデーション（削除） | フォームバリデーション確認テーブルから行削除 + シナリオ削除 |
| インタラクション（追加） | 新規シナリオ追加 |
| インタラクション（変更） | 既存シナリオの手順・期待結果を修正 |
| インタラクション（削除） | 該当シナリオを削除 |
| 状態（追加/変更） | 状態遷移テストの追加・修正 |
| フロー定義（追加） | フロー全体のE2Eシナリオを新規追加 |
| フロー定義（変更） | フロー内の遷移順序・アクションが変わった場合、関連するE2Eシナリオを修正 |
| フロー定義（画面変更） | フロー内の1画面が変更された場合、そのフローのE2Eシナリオ全体を更新対象とする |

## フローベースのE2Eシナリオ生成

### 概要

`_index.md` のフロー定義から、画面単体テストとは別に**フロー全体のE2Eシナリオ**を生成する。

### フロー → テストシナリオの変換例

フロー定義:
```
user-create --[登録ボタン]--> user-detail --[一覧に戻る]--> user-list
```

生成されるテストシナリオ:
```markdown
### シナリオ: ユーザー登録→確認→一覧フロー

**手順**:
1. `/users/new` にアクセスする
2. 各項目を入力する（user-create の画面項目を参照）
3. 「登録」ボタンをクリックする
4. `/users/:id` に遷移することを確認する
5. 登録したデータが詳細画面に表示されていることを確認する
6. 「一覧に戻る」をクリックする
7. `/users` に遷移することを確認する
8. 登録したデータが一覧に表示されていることを確認する

**期待結果**:
- [ ] 登録後、詳細画面に遷移する
- [ ] 詳細画面に登録したデータが正しく表示される
- [ ] 一覧画面に戻れる
- [ ] 一覧画面に登録したデータが表示される
```

### 差分更新時のフロー影響判定

Phase 2 の分析時に以下を追加で判定する:
1. 変更された画面が含まれるフローを `_index.md` から特定する
2. そのフローに対応するE2Eシナリオを更新対象に追加する
3. フロー定義自体が変更された場合（遷移先の変更、フロー追加・削除）もE2Eシナリオを更新する

### 到達不能画面の検知

- `_index.md` の「到達不能画面チェック」でいずれのフローにも含まれない画面を検知する
- テスト計画にも反映: 到達不能画面のテストシナリオには ⚠️ 警告を付与する

## 信号機基準（差分更新モード）

| 信号 | 基準 |
|------|------|
| 🟡 | 画面仕様の変更に基づく追加・修正（`source: screen-spec update`） |
| 🔵 | 既存シナリオで変更なし（元の信号を維持） |
| 🔴 | 画面仕様に根拠なし、AI が必要と判断した追加項目 |

差分更新で追加・修正されるシナリオには `🟡 source: screen-spec update` を付与する。既存シナリオの信号機は変更しない。

## サブエージェント戦略（差分更新モード）

| Phase | タイプ | モデル | 用途 | 並列 |
|-------|-------|--------|------|------|
| 2 | Explore | haiku | 変更差分の分析 | テスト計画数分並列 |
| 3 | general-purpose | (default) | テスト計画の更新適用 | テスト計画数分並列 |

## エスカレーション条件（差分更新モード）

以下の場合は自動処理を停止し、ユーザーに確認する:

1. **context.md 不在**: `/dev-context` を案内して終了
2. **画面仕様なし**: `/dev-screen-spec` を案内して終了
3. **テスト計画なし**: 「更新対象のテスト計画がありません」と報告して終了
4. **画面仕様とテスト計画の対応が不明**: 対応付けできなかった画面仕様を表示し、手動マッピングを依頼
5. **分析結果が大量（20件超の変更）**: ユーザーに確認後、優先度の高いものから更新

## マーカー文字列（差分更新モード）

| マーカー | 意味 |
|---------|------|
| `UPDATE_ANALYZE_SUCCESS` | 変更分析成功 |
| `UPDATE_ANALYZE_FAILED` | 変更分析失敗 |
| `UPDATE_APPLY_SUCCESS` | テスト計画更新成功 |
| `UPDATE_APPLY_FAILED` | テスト計画更新失敗 |

## ルール・制約

### 共通

- context.md が存在しない場合は `/dev-context` を案内して終了する
- モード判定は自動（ユーザー質問不要）
- `docs/dev/webtests/plans/` が存在しない場合は自動作成する
- 各生成ファイルは **500行以内**（超過時はシナリオ分割で複数ファイルに）
- Bash コマンドはプロジェクトルートの **絶対パス** を使用する（`$(git rev-parse --show-toplevel)` でルートを取得）
- サブエージェントは Task/TodoWrite 使用禁止
- メインエージェントはファイル全文を Read しない（パス確認・Grep のみ）
- サブエージェントにはファイルパスを渡し、サブエージェントが自分で Read する
- サブエージェントはマーカー＋ファイルパス＋行数のみ返す（結果本文は返さない）

### 新規生成モード固有

- plan が存在しない場合は `/dev-plan` を案内して終了する
- Phase 間のデータ受け渡しは中間ファイル（`tmp/webtest/plan/<plan-name>/`）経由
- 🔴 は完了レポートで警告表示する
- 再実行時に `draft: true` → `false` に更新可能
- Phase 6 完了後に中間ファイルディレクトリを削除する

### 差分更新モード固有

- 画面仕様が存在しない場合は `/dev-screen-spec` を案内して終了する
- Phase 間のデータ受け渡しは中間ファイル（`tmp/webtest/update/`）経由
- 差分更新で追加・修正されるシナリオには `🟡 source: screen-spec update` を付与する
- 既存シナリオの信号機は変更しない
- フロー定義の変更も影響判定に含める
- Phase 4 完了後に中間ファイルディレクトリを削除する
- 更新後に frontmatter の `screen_spec_commit`, `last_updated`, `update_history` を更新する

## 追加リソース

### リファレンスファイル

#### 新規生成モード用

- **`references/webtest-plan-format.md`** — 出力フォーマット定義（dev-webtest の test-plan-template.md を拡張）
- **`references/ac-to-scenario-mapping.md`** — Given/When/Then → webtest シナリオ変換ルール
- **`references/lightweight-inference-guide.md`** — Lightweight モードでのタスク情報→シナリオ推論ガイド
- **`references/explore-plan-prompt-template.md`** — Phase 2a: dev-plan 分析 Explore サブエージェント用プロンプト
- **`references/explore-code-prompt-template.md`** — Phase 2b: 実装コード探索 Explore サブエージェント用プロンプト
- **`references/design-prompt-template.md`** — Phase 3: 構造設計 Plan サブエージェント用プロンプト
- **`references/generate-prompt-template.md`** — Phase 5: ファイル生成 general-purpose サブエージェント用プロンプト

#### 差分更新モード用

- **`references/update-analyze-prompt-template.md`** — Phase 2: 変更分析 Explore サブエージェント用プロンプト
- **`references/update-apply-prompt-template.md`** — Phase 3: テスト計画更新適用 general-purpose サブエージェント用プロンプト
