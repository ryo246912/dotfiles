# Ralph (snarktank/ralph) 導入・使用ガイド

[Ralph](https://github.com/snarktank/ralph) は、自律型 AI エージェントループで、[Amp](https://ampcode.com) または [Claude Code](https://docs.anthropic.com/en/docs/claude-code) を繰り返し実行し、PRD (製品要件定義) のすべての項目が完了するまで実装を継続します。

## 特徴

- **クリーンなコンテキスト**: 各イテレーション（繰り返し）は新しい AI インスタンスで開始され、コンテキストがリセットされます。
- **持続的なメモリ**: Git の履歴、`progress.txt`、`prd.json` を通じて、前回の実行内容や学習事項が引き継がれます。
- **自動化**: PRD に基づいてタスクを自動的に選択し、実装、テスト、コミットを繰り返します。

## 前提条件

- 以下のいずれかの AI コーディングツールがインストールされ、認証されていること:
  - [Amp CLI](https://ampcode.com) (デフォルト)
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)
- `jq` がインストールされていること (`brew install jq`)
- Git リポジトリが構成されていること

## セットアップ

### オプション 1: プロジェクトへのコピー

Ralph のファイルをプロジェクトのルートにコピーします。

```bash
mkdir -p scripts/ralph
# ralph リポジトリからファイルをコピー
cp /path/to/ralph/ralph.sh scripts/ralph/

# ツールに応じたプロンプトテンプレートをコピー
cp /path/to/ralph/prompt.md scripts/ralph/prompt.md    # Amp 用
# または
cp /path/to/ralph/CLAUDE.md scripts/ralph/CLAUDE.md    # Claude Code 用

chmod +x scripts/ralph/ralph.sh
```

### オプション 2: Claude Code Marketplace を使用 (推奨)

Claude Code で Ralph プラグインを追加します。

```bash
/plugin marketplace add snarktank/ralph
/plugin install ralph-skills@ralph-marketplace
```

インストール後、以下のスキルが利用可能になります：

- `/prd` - PRD (製品要件定義) の生成
- `/ralph` - PRD を `prd.json` 形式に変換

## ワークフロー

### 1. PRD の作成

PRD スキルを使用して、詳細な要件ドキュメントを生成します。

```
/prd [機能の説明]
```

質問に回答すると、`tasks/prd-[機能名].md` に出力が保存されます。

### 2. Ralph 形式への変換

生成された PRD を `prd.json` に変換します。

```
/ralph tasks/prd-[機能名].md を prd.json に変換して
```

### 3. Ralph の実行

スクリプトを実行して、自律的な実装ループを開始します。

```bash
# Amp を使用する場合 (デフォルト)
./scripts/ralph/ralph.sh [最大イテレーション回数]

# Claude Code を使用する場合
./scripts/ralph/ralph.sh --tool claude [最大イテレーション回数]
```

## 重要なコンセプト

- **小さなタスク**: 各 PRD 項目は、1つのコンテキストウィンドウで完了できるサイズにする必要があります。
- **学習の蓄積**: 各イテレーション後、`progress.txt` や `AGENTS.md` (または `CLAUDE.md`) に学習内容が追記され、次の AI インスタンスがそれを読み取ります。
- **フィードバックループ**: 型チェックやテストがパスした場合のみコミットが行われます。

## デバッグと進捗確認

```bash
# 実装済みのストーリーを確認
cat prd.json | jq '.userStories[] | {id, title, passes}'

# 過去の学習内容を確認
cat progress.txt
```

---

参考: [snarktank/ralph](https://github.com/snarktank/ralph)
