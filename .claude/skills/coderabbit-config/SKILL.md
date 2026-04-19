---
name: coderabbit-config
description: CodeRabbit 向けの `.coderabbit.yaml` を、リポジトリ構成の調査と質問を踏まえて対話的に設計・生成する
author: ryo246912
version: 0.1.0
---

# coderabbit-config

この skill は `goofmint/cr-house` の用途である「CodeRabbit 向け設定ファイルを対話で生成する」流れを、この repo で試せるようにした project-local 版です。

## 使う場面

- `.coderabbit.yaml` を新規作成したい
- 既存設定を repo の実情に合わせて見直したい
- `path_instructions` を整理したい

## ゴール

- repo の主要言語、ディレクトリ構成、除外対象を把握する
- review のトーン、厳しさ、重点観点を確認する
- `.coderabbit.yaml` を最小限かつ運用しやすい形で生成する

## ワークフロー

### 1. 現状確認

最初に以下を確認する。

- 既存の `.coderabbit.yaml` / `.coderabbit.yml` があるか
- 主要ディレクトリと主要拡張子
- generated / vendor / cache / lockfile など review 対象外にしたいもの

必要なら `rg --files` で repo 全体を見て、言語やディレクトリ境界を掴む。

### 2. 質問

以下を中心に、必要最小限の質問を行う。

- どの言語やファイル種別を重点 review 対象にするか
- レビューの tone を厳しめにするか、軽めにするか
- 自動生成物や第三者管理ディレクトリを除外するか
- shell / markdown / SQL / workflow などで個別観点を持たせるか
- PR summary や high-level review をどこまで求めるか

### 3. 設計

質問結果と repo 調査を踏まえ、以下を組み立てる。

- review の基本方針
- ignore 対象
- `path_instructions`
- 必要なら language / labeling / knowledge 系の補助設定

不確かな key を増やしすぎず、まずは保守しやすい最小構成を優先する。

### 4. 生成

`.coderabbit.yaml` を生成する。既存ファイルがある場合は上書き前に差分方針を説明する。

### 5. 仕上げ

最後に以下を短くまとめる。

- 生成した設定の意図
- 強めに効く `path_instructions`
- あとで調整しやすいポイント

## 設定時の指針

- generated file や lockfile は review 価値が低ければ除外を優先する
- `path_instructions` は「ディレクトリ単位」か「拡張子単位」で読みやすく保つ
- shell script には安全性と portability、markdown には記述品質、設定ファイルには整合性の観点を与えると扱いやすい
- unsure な schema を憶測で増やさず、必要なら conservative な YAML に留める

## 期待する呼び出し例

```text
.coderabbit.yaml を作成して
```

```text
CodeRabbit の設定をこの repo 向けに作りたい
```
