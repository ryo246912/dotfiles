---
name: dev-verify
description: This skill should be used when the user asks to "dev-verify", "実装の検証", "完了チェック", "verify implementation", "全テスト実行", "run all tests", "dev-verify auth". Plan単位で全タスクの完了状態とテスト・ビルド・Lintの整合性を検証し、レポートを出力する。
argument-hint: '<plan-name>'
---

# Dev Verify

Plan単位ですべてのタスクの完了状態を確認し、全テスト実行・ビルド・Lint・ファイルサイズチェックを行い、検証レポートを `docs/dev/plans/<plan-name>/reports/` に出力する。

## 前提知識

### dev-*スキルフロー内の位置

```
dev-context → dev-plan → dev-impl → [dev-verify]
                                ↘ dev-debug
```

### 引数フォーマット

```
/dev-verify <plan-name>
```

## ワークフロー

### Step 1: タスク完了チェック

`docs/dev/plans/<plan-name>/tasks/` 内の全タスクファイルを読み込み、フロントマターの `status` を確認する。

- すべて `done` → Step 2 へ進む
- `pending` / `in_progress` のタスクがある → ユーザーに未完了タスクの一覧を報告し、続行するか確認する（AskUserQuestion）

### Step 2: 全テスト実行

`docs/dev/context.md` からテスト実行コマンドを取得し、全テストを実行する。

```bash
# context.md の Test Framework セクションからコマンドを取得
<test-command>
```

テスト結果を記録する: passed / failed / skipped の件数。

### Step 3: カバレッジチェック

`docs/dev/context.md` の Test Framework セクションから Coverage Command と Coverage Threshold を取得し、プロジェクト全体のカバレッジを計測する。

1. Coverage Command でプロジェクト全体のカバレッジを計測する
2. パッケージごとにカバレッジ率を抽出し、閾値と比較する
3. `[no test files]` は 0% として扱う
4. 閾値未達のパッケージは Issues Found に記録する

### Step 4: ビルド確認

コンパイル言語やビルドステップがある場合、ビルドコマンドを実行する（context.md から取得）。

インタープリタ言語でビルドステップがない場合はスキップする。

### Step 5: Lint実行

context.md に Lint コマンドが記載されている場合、実行する。記載がない場合はスキップする。

### Step 6: ファイルサイズチェック（500行ルール）

Planで変更・作成されたファイル（各タスクファイルの Files セクションから収集）の行数を確認する（絶対パスを使用）:

```bash
wc -l "$(git rev-parse --show-toplevel)/<ファイルの相対パス>"
```

500行を超えるファイルがあれば警告として記録する。

### Step 7: 信号機サマリー

Plan内の全タスクの確信度レポートを集約する:

- 🟡 妥当な推測の項目一覧（ユーザー確認推奨）
- 🔴 AI推論補完の項目一覧（人間の確認必須）

🔴 が残っている場合は明確に警告する。

### Step 8: レポート出力

検証結果を `docs/dev/plans/<plan-name>/reports/verify-YYYY-MM-DD.md` に出力する。

```markdown
# Verification Report - YYYY-MM-DD
## Plan: <plan-name>

## Summary

| Item | Result |
|------|--------|
| Tasks | X/Y completed |
| Tests | Z passed, W failed, V skipped |
| Coverage | X/Y packages above threshold (threshold: 80%) |
| Build | OK / NG / N/A |
| Lint | OK / NG / N/A |
| 500-line rule | OK / X files over limit |

## Task Status

| ID | Title | Status |
|----|-------|--------|
| 001 | ... | done |
| 002 | ... | done |

## Test Results

[テスト実行の出力サマリー]
[失敗テストがある場合は詳細]

## Coverage Results

| パッケージ | カバレッジ | 閾値 | 結果 |
|-----------|----------|------|------|
| internal/handler | XX.X% | 80% | OK / NG |

[閾値未達パッケージの詳細（ある場合）]

## File Size Check

[500行超過ファイルの一覧（ある場合）]

## Confidence Summary

### 🟡 妥当な推測（要確認）
- [ファイル](パス) — [確認すべき点]

### 🔴 AI推論補完（人間の確認必須）
- [ファイル](パス) — [判断が必要な理由]

## Issues Found

[検出された問題の詳細]

## Recommendations

[問題がある場合の次アクション提案]
- テスト失敗 → `/dev-debug` の使用を推奨
- 500行超過 → `/dev-impl` のリファクタリングを推奨
- 🔴 残存 → 該当ファイルの人間レビューを推奨
```

### Step 9: Docker クリーンアップ

プロジェクトルートに `docker-compose.yml` または `docker-compose.yaml` が存在するか確認する。存在する場合:

1. `docker compose down` を実行してコンテナを停止する
2. 停止に失敗した場合はユーザーに報告する（ブロッキングにしない）

## ルール・制約

- context.md が存在しない場合、テスト・ビルド・Lintコマンドが不明であることを報告し、可能な範囲で検証する
- テスト失敗がある場合でもレポートは出力する（中断しない）
- レポートファイルが既存の場合は日付が異なれば新規ファイルとして作成し、同日であれば上書きする
- テスト実行はサブエージェントではなく直接 Bash で実行する（結果の全文がレポートに必要）
- カバレッジ閾値未達のパッケージがある場合は VERIFY_ISSUES_FOUND とする
- Lint/ビルドコマンドが context.md にない場合はスキップし、レポートに N/A と記載する
- Bash コマンドはプロジェクトルートの **絶対パス** を使用する（`$(git rev-parse --show-toplevel)` でルートを取得）
