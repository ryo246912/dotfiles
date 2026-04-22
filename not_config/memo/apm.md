# Agent Package Manager (APM) による外部スキル管理

このプロジェクトでは、外部のAIエージェント用スキルやパッケージを効率的に導入・管理するために [APM](https://github.com/microsoft/apm) を導入しています。

## コンセプト

- **カスタムスキル**: 既存の `rulesync` 等で管理を継続します（`.apm` 内には配置しません）。
- **外部スキル**: APMを使用して `apm.yml` で依存関係を管理し、プロジェクトに導入します。

## 使い方

### 1. 外部パッケージの追加

```bash
apm install <owner>/<repo>
# 例: apm install microsoft/apm-sample-package
```

### 2. 設定のコンパイル

インストールした外部スキルの指示などを、各エージェントが読み込める形式（`CLAUDE.md`, `AGENTS.md` 等）に反映させます。

```bash
mise run apm-compile
# または
apm compile --target all
```

これにより、外部パッケージに含まれる指示が自動的に集約されます。

## ディレクトリ構成

- `apm.yml`: 外部パッケージのリストとバージョン管理。
- `.apm/`: APMが使用するローカルプリミティブ格納用（通常は空で、外部パッケージのキャッシュ等は `apm_modules` に作成されます）。

## 各エージェントへの影響

- **Claude Code**: `CLAUDE.md` に外部スキルの指示が追加されます。
- **Copilot / Codex**: `AGENTS.md` に外部スキルの指示が追加されます。

## 注意事項

- `apm compile` は `CLAUDE.md` や `AGENTS.md` を自動生成するため、これらのファイルを手動で編集する場合は、APMによる上書きを考慮する必要があります。
- 現在の運用では、プロジェクト独自の主要な指示は `CLAUDE.md` に直接記述されており、APMは主に追加の外部機能を「差し込む」ために利用します。
