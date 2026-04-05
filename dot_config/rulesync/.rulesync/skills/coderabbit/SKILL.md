---
name: coderabbit
description: CodeRabbit CLI を使って未コミット差分の自動レビューと修正ループを回す skill。公式 code-review skill 相当の用途で使う。
targets:
  - claudecode
  - codexcli
---

# CodeRabbit CLI による自律レビュー

## 概要

CodeRabbit CLI を使用して、未コミット差分に対するレビューと修正のループを自律実行します。
この skill は CodeRabbit 公式の `code-review` skill 相当の用途を想定しています。
既存 PR のレビューコメント対応は `review-fix` に分離し、この skill では扱いません。

## 使うタイミング

- 実装や設定変更を一段落させたあと
- ユーザーが「レビューして」「CodeRabbit を回して」などと求めたとき
- 最終報告前に重大な取りこぼしがないか確認したいとき

## 実行手順

### 1. レビュー対象を確認する

- `git status --short` でレビュー対象の差分があることを確認します。

### 2. CodeRabbit をバックグラウンドで実行する

既定は AI agent 向けの prompt-only モードです。

```bash
coderabbit review --prompt-only --type uncommitted
```

プレーンテキストが必要な場合は以下を使います。

```bash
coderabbit review --plain --type uncommitted
```

### 3. 指摘を評価して修正する

- CodeRabbit の完了まで定期的に確認します。
- Critical / High / major issue を優先して修正します。
- 根拠の弱い nit や単なる好みの差異は無理に追わないでください。
- 単純な修正候補はそのまま反映して構いません。

### 4. 1 回だけ再レビューする

- 修正後にもう一度 `coderabbit review --prompt-only --type uncommitted` を実行します。
- 2 周目で重大な指摘がなければ終了します。
- 無限ループを避けるため、再レビューは最大 1 回までにしてください（合計 2 パスまで: 初回 + 1 回の再レビュー）。

## 注意点

- CodeRabbit のレビューは 7〜30 分以上かかることがあります。長時間タスクとして扱ってください。
- CLI 認証や rate limit で失敗した場合は、その事実を明示して別の修正フローに切り替えてください。
- 補助指示が必要な場合は `coderabbit review -c .coderabbit.yaml --prompt-only --type uncommitted` のように repo の設定ファイルを追加できます。
- PR が作成済みで、既存コメントへの返信や修正が必要な場合は `review-fix` を使ってください。
