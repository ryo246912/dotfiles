# Archon 導入・使用ガイド

[Archon](https://github.com/coleam00/Archon) は、AI コーディングエージェントのためのワークフローエンジンです。

## 導入方法

### 1. CLI のインストール

以下のコマンドで Archon CLI をインストールできます。

    curl -fsSL https://archon.diy/install | bash

### 2. Claude Code への統合

本リポジトリでは rulesync を通じて Archon の Skill を Claude Code に同期するように設定されています。

## 主な使い方

### ワークフローの実行

    archon workflow run <workflow-name> --branch <branch-name> "<message>"

### 利用可能な標準ワークフロー

| ワークフロー                   | 内容                                       |
| ------------------------------ | ------------------------------------------ |
| archon-assist                  | 汎用的なデバッグ・コード探索               |
| archon-fix-github-issue        | GitHub Issue の調査から修正 PR 作成まで    |
| archon-idea-to-pr              | アイデアから PR 作成までのフルパイプライン |
| archon-comprehensive-pr-review | 5 つのエージェントによる詳細な PR レビュー |
| archon-resolve-conflicts       | コンフリクトの自動解消                     |

### ワークフローの確認

    archon workflow list
