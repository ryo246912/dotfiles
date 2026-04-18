# Agent Package Manager (APM) によるスキル管理

このプロジェクトでは、AIエージェント（Claude Code, Copilot CLI, Codex等）の設定やスキルを管理するために [APM](https://github.com/microsoft/apm) を導入しています。

## ディレクトリ構成

- `apm.yml`: プロジェクトのAPM構成ファイル。依存関係やスクリプトを定義します。
- `.apm/`: ローカルのAPMプリミティブ（スキル、指示、プロンプト等）を格納するディレクトリ。
  - `skills/`: 各スキルの定義 (`SKILL.md`)。バージョン管理の対象となります。
  - `instructions/`: エージェントへの指示 (`.instructions.md`)。コンパイル対象です。
  - `chatmodes/`: チャットモードの定義 (`.chatmode.md`)。

## 使い方

### 1. スキルのコンパイル

APMのプリミティブを各エージェントが読み込める形式（`CLAUDE.md`, `AGENTS.md` 等）にコンパイルします。

```bash
mise run apm-compile
# または
apm compile --target all
```

これにより、プロジェクト内のすべての指示とスキルがエージェントに共有されます。

### 2. 新しいスキルの追加

1. `.apm/skills/スキル名/SKILL.md` を作成します。
2. これをエージェントに読み込ませるには、`.apm/instructions/スキル名.instructions.md` に内容をコピー（またはリンク）し、フロントマターに `applyTo: "**"` を指定してください。

### 3. 依存関係のインストール

外部のAPMパッケージをインストールして、プロジェクトで共通のスキルや指示を利用できます。

```bash
apm install <owner>/<repo>
```

## rulesync との関係

- **APM**: プロジェクト固有のスキル管理と、エージェント向け構成ファイルの生成を担当します。プロジェクトの `apm.yml` でバージョン管理が可能です。
- **rulesync**: 複数のプロジェクト間でのグローバルなルール同期や、エージェントごとの詳細な設定（hooks, commands等）を担当します。

基本的には、プロジェクト固有の「スキル」はAPMで管理し、マシン全体の「ルール」は rulesync で管理することを推奨します。

## 各エージェントへの適用

- **Claude Code**: `CLAUDE.md` を自動的に読み込みます。
- **Copilot / VSCode**: `AGENTS.md` を自動的に読み込みます。
- **Codex / Others**: `AGENTS.md` または `CLAUDE.md` を通じてプロジェクトの文脈を理解します。

## 注意事項

- `CLAUDE.md` や `AGENTS.md` は `apm compile` によって上書きされます。
- 元の `CLAUDE.md` の内容は `.apm/instructions/overview.instructions.md` に移行済みです。
