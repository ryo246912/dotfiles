---
root: true
targets:
  - claudecode
globs:
  - "**/*"
---

# CLAUDE.md

- 必ず日本語で回答してください。

## Git操作ポリシー

- **ブランチ作成・切り替え**：ユーザーが行う。
- **コミット**：ユーザーが明示的に指示した場合か、作業を区切りたい場合のみ行う
  - 基本的にはコミットしない

## コミット前に確認すること（必ず実施）

- コミット前には必ず動作確認を行って動作が問題ないかを確認してください
  - コミットする際はエラーがない状態で行ってください

## AutoHarness プロトコル

このプロジェクトでは、DeepMind の AutoHarness 論文の思想を応用した、プロジェクト固有のコード検証ハーネスを導入しています。

### 構成要素

1. **自然言語ルール** (`.claude/rules/harness.md`): プロジェクト固有の命名規則、コーディング規約、禁止パターン。
2. **検証スクリプト** (`.claude/rules/harness_check.py`): 型チェック、lint、テストを一括実行し、結果を JSON で返す。

### Claude Code の動作指針

#### 1. 変更の検証
コードを変更する前後に、以下のコマンドを実行してコードの正当性を確認してください。
```bash
python .claude/rules/harness_check.py <対象ファイル>
```

#### 2. ハーネスの初期化 (`/autoharness-init`)
ユーザーが `/autoharness-init` を実行した場合、`autoharness-init` スキルを使用して、プロジェクトを解析し `harness.md` と `harness_check.py` を生成してください。
その際、`dot_local/bin/autoharness-generate-check` をテンプレートとして活用してください。

#### 3. ハーネスの自動改善 (`/autoharness-update`)
以下のシグナルを検知した際、または明示的に `/autoharness-update` が実行された際、`autoharness-update` スキルを使用してハーネスを自律的に更新してください。
- コード生成タスクが一段落したとき
- 型エラー・テスト失敗・lintエラーが発生したとき
- ユーザーから修正フィードバック（「うちではXXXを使う」等）があったとき

更新時は `@.claude/rules/harness.md` を参照して現在のルールを把握し、必要に応じてルールとスクリプトを強化してください。
