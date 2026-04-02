---
name: autoharness
description: |
  AutoHarness — プロジェクト固有のコード検証ハーネスを自動生成し、Claude Codeが生成するコードの精度を向上させるスキル。
  DeepMindのAutoHarness論文（arXiv:2603.03329）のアイデアを応用し、「このプロジェクトで有効なコード変更とは何か」を
  自然言語ルールと実行可能な検証スクリプトの両方として自動生成する。

  使用タイミング：
  - `/autoharness-init` — ユーザーがこのコマンドを入力したとき。プロジェクト初回セットアップ
  - `/autoharness-update` — コード生成タスクが一段落したとき、型エラー・テスト失敗・lintエラーが発生したとき、
    ユーザーからフィードバック（「違う」「こうしてほしかった」「うちではXXXを使う」等）があったとき、
    またはユーザーが明示的に /autoharness-update と入力したとき。
    ユーザーがコマンドを入力しなくても自律的に実行すること。
---

# AutoHarness スキル

## 概念

AutoHarness（DeepMind, 2026）のアイデアをClaude Codeのコーディングタスクに適用する。

論文では「ゲームの不正手」を防ぐハーネスを自動生成した。Claude Codeでの「不正手」とは：
- 型エラー・コンパイルエラーになるコード
- テストを壊すコード
- lintルール違反のコード
- プロジェクト固有の命名規則・構成ルールの違反

これを防ぐために：
1. **自然言語ルール**（`.claude/rules/harness.md`）— Claude Codeが参照・内面化する
2. **検証スクリプト**（このスキルの`scripts/validate.py`）— 実際にコードを実行して検証する

の両方を生成・維持する。

https://arxiv.org/abs/2603.03329v1

---

## コマンド: `/autoharness-init`

**目的:** プロジェクトを初回解析してハーネスを生成する

### 手順

#### Step 1: プロジェクト解析

以下を調べる（並列で実行する）：

```
- 言語・フレームワーク: package.json / pyproject.toml / Cargo.toml / go.mod 等
- テストコマンド: scripts, Makefile, README
- Lintツール: .eslintrc, .flake8, ruff.toml, biome.json 等
- 型チェック: tsconfig.json, mypy.ini, pyrightconfig.json 等
- ビルドコマンド: CI設定（.github/workflows/, .gitlab-ci.yml）
- 命名規則・ファイル構成: 既存コードのパターンを数ファイルサンプリング
- CLAUDE.md: 既存のルールがあれば読み込む
```

#### Step 2: ハーネスルールの生成

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

#### Step 3: 検証スクリプトの生成

`.claude/rules/harness_check.py` を生成する。このスクリプトは：
- `python .claude/rules/harness_check.py [対象ファイルパス...]` で実行できる
- 内部でプロジェクトの型チェック・lint・テストを呼び出す
- 結果をJSON形式で出力する（`{"passed": true/false, "errors": [...], "warnings": [...]}`）

スクリプトの実装は `scripts/generate_harness_check.py` を使って生成する（後述）。

#### Step 4: CLAUDE.md への参照追記

`CLAUDE.md` に以下を追記（既存内容は保持）：

```markdown
## AutoHarness

@.claude/rules/harness.md

このプロジェクトのコード検証ルールは `.claude/rules/harness.md` を参照。
コード変更前後に `python .claude/rules/harness_check.py <ファイル>` を実行して検証できる。
```

#### Step 5: 完了報告

ユーザーに以下を伝える：
- 生成したファイルの一覧
- 検出した主要な制約（型チェックツール名、テストコマンド等）
- `python .claude/rules/harness_check.py --help` で使い方を確認できること

---

## コマンド: `/autoharness-update`

**目的:** フィードバックや失敗をもとにハーネスを改善する

このコマンドは次の文脈で使う：
- ユーザーが明示的に `/autoharness-update` と入力した
- コード生成後に型エラー・テスト失敗・lintエラーが出た
- ユーザーが「この出力はおかしい」「違う」「こうしてほしかった」と言った

### 手順

#### Step 1: 失敗の分析

現在の会話・エラーメッセージ・差分から「何が失敗したか」を特定する：

```
- エラーの種類（型エラー / テスト失敗 / lint / ロジック誤り / スタイル違反）
- 失敗したファイルと行番号
- 根本原因（ルールが不足 / ルールが曖昧 / スクリプトが未対応）
```

#### Step 2: ハーネスの弱点特定

AutoHarness論文の refinement ループと同様に考える：

> 「is_legal_action()がTrueを返したが実際には不正だった」→ 検証関数の漏れ
> 「is_legal_action()がFalseだが実際には正当だった」→ 検証関数の過剰制約

Claude Codeの文脈では：
- ルールに書いてあったのに違反したコードを生成した → ルールの説明が不明瞭
- ルールにないケースで失敗した → 新しいルールが必要
- スクリプトが検出できなかった → スクリプトを強化

#### Step 3: ハーネスの更新

`.claude/rules/harness.md` と `.claude/rules/harness_check.py` を更新する：

- 曖昧なルールは具体例付きで書き直す
- 不足しているルールを追加する
- スクリプトに新しいチェックを追加する

更新時は **なぜその変更が必要か** をルールのコメントとして残す。

#### Step 4: 完了報告

- 何を変更したか（diff形式で簡潔に）
- 追加したルールの意図
- 「`/autoharness-update` を繰り返すことでハーネスが改善されます」と案内

---

## スクリプト: `scripts/generate_harness_check.py`

このスクリプト自体はスキル内に置かれており、プロジェクトに依存しない。
`/autoharness-init` の Step 3 で、このスクリプトを **参考テンプレートとして読み込み**、
プロジェクト固有の内容を埋めた `.claude/rules/harness_check.py` を生成する。

生成されるスクリプトの仕様：

```python
# .claude/rules/harness_check.py
# このファイルはautoharness-initで自動生成された。autoharness-updateで更新される。

import subprocess, sys, json
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent  # .claude/rules/ から3階層上

CHECKS = {
    "typecheck": "<型チェックコマンド>",
    "lint": "<lintコマンド>",
    "test": "<テストコマンド>",  # ファイル指定がある場合は対象ファイルを引数に
}

def run_check(name, cmd, files=None):
    ...

def main():
    files = sys.argv[1:] if len(sys.argv) > 1 else []
    results = {}
    for name, cmd in CHECKS.items():
        results[name] = run_check(name, cmd, files)
    passed = all(r["passed"] for r in results.values())
    print(json.dumps({"passed": passed, "results": results}, indent=2, ensure_ascii=False))
    sys.exit(0 if passed else 1)
```

---

## 設計の原則

**AutoHarness論文との対応：**

| 論文の概念 | このスキルでの対応 |
|---|---|
| `is_legal_action()` | `harness_check.py` の各チェック |
| `propose_action()` | Claude Codeのコード生成 |
| Refinement loop | `/autoharness-update` の反復呼び出し |
| Environment feedback | エラーメッセージ・テスト結果 |
| Thompson sampling | （今回はシンプルに線形改善） |

**重要な設計判断：**
- `harness_check.py` はスキルの `scripts/` ではなくプロジェクトの `.claude/rules/` に置く
  — プロジェクトごとに内容が異なるため
- スキルの `scripts/generate_harness_check.py` はテンプレート生成の参考として使う
  — プロジェクトに依存しない汎用ロジックはここに集約
- ルールファイルはClaude Codeが毎回参照できるよう `.claude/rules/` に置く
  — `CLAUDE.md` からの参照で自動的に文脈に入る
