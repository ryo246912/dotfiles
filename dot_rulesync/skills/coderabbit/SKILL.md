---
name: coderabbit
description: CodeRabbit CLI を使って PR やコミットの自動レビューを実行する skill。prompt-only と plain の切り替え、実行手順、結果活用が必要なときに使う。
targets:
  - claudecode
  - codexcli
  - geminicli
  - copilot
---

# CodeRabbit CLI によるコード自動レビュー

## 概要

CodeRabbit CLI を使用して、プルリクエストやコミットに対して自動的にコードレビューを実行します。レビュー結果は、プロンプトモードまたはプレーンモードで取得できます。

## 役割と作業フロー

### 1. モードの選択

CodeRabbit は 2 つのモードで実行できます。

#### プロンプトモード（デフォルト）

```bash
coderabbit --prompt-only
```

- CodeRabbit の対話的なプロンプトを通じてコードレビューを実行
- ユーザーとのやり取りを通じて、詳細なレビューコメントを生成
- PIR（Pull Request Review）の形式で結果が得られる

#### プレーンモード

```bash
coderabbit --plain
```

- シンプルなテキスト形式でコードレビュー結果を出力
- プログラム的な処理や自動化に適した形式
- 構造化されたレビュー内容を取得できる

### 2. 実行方法

重要: CodeRabbit は必ずバックグラウンドタスクで実行してください。他のコマンドを同時に実行しないでください。

```bash
coderabbit [--prompt-only | --plain]
```

### 3. レビュー結果の活用

- CodeRabbit からのレビューコメントを確認
- レビュー内容に基づいてコードを改善

## オプション設定

CodeRabbit の実行時に、以下のオプションを指定できます。

- `--prompt-only`: 対話的なプロンプトモードを使用（デフォルト）
- `--plain`: シンプルなテキスト形式でレビュー結果を出力
- その他のオプションについては、`coderabbit --help` で確認
