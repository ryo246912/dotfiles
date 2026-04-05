# DOTFILE-98 renovate の Patch 除外ルール修正

## 概要

- `aqua:aws/aws-cli` の Patch 更新 PR が作成されている原因を特定し、renovate の除外ルールが意図どおり効く状態に戻す。
- 同じルールで列挙している他ツールにも同種の不整合がないか確認し、修正範囲を明確にする。

## 要件

### 機能要件

- `.github/renovate.json` の Patch 除外ルールが `aqua:aws/aws-cli` に対して正しく適用されること。
- 同一ルールに列挙している `ubi:superfly/flyctl`、`aqua:stripe/stripe-cli`、`usage`、`ubi:render-oss/cli`、`npm:renovate`、`cosign`、`rust`、`ubi:pdm-project/pdm` にも意図どおり適用されること。
- 除外対象の列挙方法が、Renovate が抽出する依存識別子と一致していること。

### 非機能要件

- 既存の Renovate 設定の意図を崩さず、最小差分で修正すること。
- 設定変更後も `renovate-config-validator` を通過すること。
- ローカル検証の根拠を残し、Human Review 時点で修正妥当性を説明できること。

### 制約条件

- 変更対象は `dotfiles` リポジトリ内に限定する。
- 実装前にユーザー承認を待ち、計画段階ではコード変更を行わない。
- GitHub token 非依存で再現できるローカル検証を優先する。

## 調査結果

- `renovate 42.70.3 --platform=local --dry-run=extract` で、`aqua:aws/aws-cli` は `depName = aqua:aws/aws-cli`、`packageName = aws/aws-cli` と抽出された。
- Renovate 公式ドキュメントでは、`matchPackageNames` は `packageName` を、`matchDepNames` は `depName` を対象にする。
- 現在の `packageRules` は `matchPackageNames` に `aqua:aws/aws-cli` など `depName` ベースの値を並べているため、`aws-cli` 以外を含めて列挙対象の多くが一致しない。
- 同じ不一致を確認できた対象:
  - `ubi:superfly/flyctl` -> `packageName = superfly/flyctl`
  - `aqua:stripe/stripe-cli` -> `packageName = stripe/stripe-cli`
  - `usage` -> `packageName = jdx/usage`
  - `ubi:render-oss/cli` -> `packageName = render-oss/cli`
  - `npm:renovate` -> `packageName = renovate`
  - `aqua:aws/aws-cli` -> `packageName = aws/aws-cli`
  - `cosign` -> `packageName = sigstore/cosign`
  - `rust` -> `packageName = rust-lang/rust`
  - `ubi:pdm-project/pdm` -> `packageName = pdm-project/pdm`

## 実装計画

### 1. Patch 除外ルールの一致条件を修正する

- `.github/renovate.json` の対象ルールで `matchPackageNames` を `matchDepNames` に置き換える。
- 既存の依存識別子リストは維持し、意図した依存だけが最小差分で対象になるようにする。

### 2. 列挙済みツール全体への影響を確認する

- local dry-run extract のログを使い、列挙済み 9 件すべてが `depName` と一致することを再確認する。
- `cosign` など manager をまたいで名前が出る依存が想定どおりかを確認し、必要なら plan にリスクを明記する。

### 3. 設定変更後の検証を行う

- `renovate-config-validator --strict` で設定妥当性を確認する。
- `renovate --platform=local --dry-run=extract` を再実行し、抽出される `depName` と修正後ルールの対応関係を確認する。
- GitHub token がないため GitHub datasource の完全な lookup は限定されるが、少なくとも `npm:renovate` のような token 非依存な依存でルール適用確認が可能かを確認する。

## 変更対象ファイル

- `.github/renovate.json`

## 技術的課題と対応策

- GitHub datasource は token なしだと lookup が一部スキップされる。
  - 対応策: `extract` ログで `depName` と `packageName` の差異を確認し、設定変更の正当性を担保する。
- `cosign` のように manager 固有プレフィックスがない依存は、別 manager に同名依存があれば同時にマッチする可能性がある。
  - 対応策: 実装時に抽出結果を見て影響範囲を再確認し、必要なら `matchManagers` 追加を検討する。

## テスト計画

- `env -i PATH=/Users/ryo./.local/share/mise/installs/node/22.19.0/bin:/usr/bin:/bin /Users/ryo./.local/share/mise/installs/node/22.19.0/bin/node /Users/ryo./.local/share/mise/installs/npm-renovate/42.70.3/node_modules/renovate/dist/config-validator.js --strict`
- `env -i HOME=/Users/ryo. LOG_LEVEL=debug PATH=/Users/ryo./.local/share/mise/installs/node/22.19.0/bin:/usr/bin:/bin /Users/ryo./.local/share/mise/installs/node/22.19.0/bin/node /Users/ryo./.local/share/mise/installs/npm-renovate/42.70.3/node_modules/renovate/dist/renovate.js --platform=local --dry-run=extract`
- 必要に応じて `--dry-run=lookup` を対象依存に絞って実行し、Patch 更新が除外されるログを確認する。

## リスクと未解決事項

- `matchDepNames` へ切り替えることで、同名 `depName` を持つ別 manager の依存にもルールが適用される可能性がある。
- GitHub token なしでは GitHub datasource の完全な更新候補計算をローカルで再現しきれないため、検証は抽出結果と validator 中心になる。
