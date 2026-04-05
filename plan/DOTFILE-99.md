# DOTFILE-99 計画

## 概要

- PR #772 で追加された Atuin 向け Renovate グルーピング案を、現在の `main` に合わせて再設計する。
- `dot_config/mise/config.toml` の Atuin CLI 更新と `dot_config/atuin/fly.toml` の Docker image 更新を同一 PR にまとめる。
- `aqua` のような backend 名を個別列挙しなくても拾えるマッチ条件に寄せる。

## 要件

### 機能要件

- Renovate が Atuin 関連更新を 1 つのグループとして扱えること。
- `mise` 側の Atuin 更新と `fly.toml` 側の Docker image 更新が同じ `groupName` に入ること。
- backend 依存の表記揺れがあっても Atuin 更新を取りこぼしにくいこと。

### 非機能要件

- 既存の `packageRules` を壊さず、現在の `.github/renovate.json` に自然に統合すること。
- ルールは将来の backend 追加時にも読める構造にすること。
- JSON フォーマットと既存 lint を通せること。

### 制約条件

- 実装対象はこのリポジトリ内に限定する。
- 共有 preset `github>ryo246912/renovate-config` には手を入れない。
- PR #772 は `main` と競合しているため、その差分をそのまま流用しない。

## 調査結果

- 現在の `main` の `.github/renovate.json` には既存 `packageRules` があり、PR #772 の差分は古いファイル状態を前提にしている。
- `dot_config/mise/config.toml` では Atuin が `"aqua:atuinsh/atuin"` として定義されている。
- `dot_config/atuin/fly.toml` では Atuin Docker image が `ghcr.io/atuinsh/atuin:v18.8.0` として定義されている。
- PR #772 には「`atuin` の短縮名や backend 非依存マッチも考慮したい」というレビューが付いている。
- 一方で bot コメント間で `depName` / `packageName` の解釈が食い違っているため、実装時は Renovate の抽出結果を確認してから matcher を確定する。
- この環境では `renovate` shim が `mise.toml` の trust 判定に引っかかるため、dry-run は shim 以外の起動経路も含めて確認する必要がある。

## 実装計画

### 1. Renovate ルールの統合

- `.github/renovate.json` の既存 `packageRules` 配列へ Atuin 用ルールを追加する。
- `groupName` は PR #772 と同じく `atuin` を使う。
- backend 名の個別列挙を減らせるよう、短縮名と backend 付き表記の両方を吸収できる matcher を選ぶ。
- 必要なら `matchPackageNames` と `matchDepNames` を役割分担して使い、Docker image 側の表記も同じルールに束ねる。

### 2. 抽出名の確認と調整

- Renovate の dry-run か同等の確認手段で、Atuin CLI と Docker image がそれぞれどう抽出されるか確認する。
- `aqua` などの backend 付き表記、短縮名 `atuin`、Docker image 側の名前がすべて新ルールで拾えることを確認する。
- dry-run がこの環境で再現できない場合は、レビューコメントと既存ファイル値を根拠に最小安全側の matcher を選び、検証不能点を記録する。

### 3. 検証

- `mise run lint-json` で `.github/renovate.json` のフォーマット整合を確認する。
- 可能なら Renovate local dry-run で Atuin 関連更新が同一グループ名になることを確認する。
- 差分を確認し、既存の patch 無効化ルールが保持されていることを確認する。

## 変更対象ファイル

- `.github/renovate.json`
- `plan/DOTFILE-99.md`

## 検証方法

- `git diff -- .github/renovate.json`
- `mise run lint-json`
- `LOG_LEVEL=debug renovate --token \"$(gh auth token)\" --dry-run --platform=local`

## リスクと未解決事項

- Renovate が `mise` の Atuin を `atuin` として扱うのか、`aqua:atuinsh/atuin` として扱うのかは dry-run で最終確認が必要。
- `fly.toml` の Docker image 側が `ghcr.io/atuinsh/atuin` のまま抽出されるか、正規化された名前になるかで matcher の書き方が変わる可能性がある。
- PR #772 は `main` と競合中のため、このチケットでは現在の `main` 基準で改めて差分を作る前提にする。
- 実装時に Renovate dry-run を行うには、`mise trust` に依存しない実行方法を先に確保する必要がある。
