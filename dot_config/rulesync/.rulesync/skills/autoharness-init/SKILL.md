---
name: autoharness-init
description: |
  AutoHarness 初回セットアップコマンド。
  プロジェクトを解析して .claude/rules/harness.md（自然言語ルール）と
  .claude/rules/harness_check.py（検証スクリプト）を自動生成する。
  ユーザーが /autoharness-init と入力したときに使用する。
---

# `/autoharness-init` — AutoHarness 初回セットアップ

プロジェクトを解析してハーネスを生成します。

## 手順

### Step 1: プロジェクト解析（並列で実行）

以下を調べる：

```
- 言語・フレームワーク: package.json / pyproject.toml / Cargo.toml / go.mod 等
- テストコマンド: scripts, Makefile, README
- Lintツール: .eslintrc, .flake8, ruff.toml, biome.json 等
- 型チェック: tsconfig.json, mypy.ini, pyrightconfig.json 等
- ビルドコマンド: CI設定（.github/workflows/, .gitlab-ci.yml）
- 命名規則・ファイル構成: 既存コードのパターンを数ファイルサンプリング
- CLAUDE.md: 既存のルールがあれば読み込む
```

### Step 2: ハーネスルールの生成

解析結果をもとに `.claude/rules/harness.md` を生成する。

以下のセクションで構成する：

```markdown
# AutoHarness ルール

## 検証コマンド
このプロジェクトでコードの正当性を確認するコマンド：
- 型チェック: `<コマンド>`
- テスト: `<コマンド>`
- Lint: `<コマンド>`
- ビルド: `<コマンド>`

## 有効なコード変更の条件 (is_legal_change)
1. ...
2. ...

## 命名規則
- ファイル名: ...
- 関数名: ...
- 変数名: ...

## 禁止パターン
- ...

## プロジェクト固有の注意事項
- ...
```

### Step 3: 検証スクリプトの生成

`.claude/rules/harness_check.py` を生成する。このスクリプトは：
- `python .claude/rules/harness_check.py [対象ファイルパス...]` で実行できる
- 内部でプロジェクトの型チェック・lint・テストを呼び出す
- 結果をJSON形式で出力する（`{"passed": true/false, "errors": [...], "warnings": [...]}`）

### Step 4: CLAUDE.md への参照追記

`CLAUDE.md` に以下を追記（既存内容は保持）：

```markdown
## AutoHarness

@.claude/rules/harness.md

このプロジェクトのコード検証ルールは `.claude/rules/harness.md` を参照。
コード変更前後に `python .claude/rules/harness_check.py <ファイル>` を実行して検証できる。
```

### Step 5: 完了報告

ユーザーに以下を伝える：
- 生成したファイルの一覧
- 検出した主要な制約（型チェックツール名、テストコマンド等）
- `python .claude/rules/harness_check.py --help` で使い方を確認できること