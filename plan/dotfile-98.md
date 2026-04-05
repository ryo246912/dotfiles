# DOTFILE-98 renovate の Patch 除外ルール修正

## 概要

- `aqua:aws/aws-cli` の Patch 更新 PR が作成されている原因を特定し、renovate の除外ルールが意図どおり効く状態に戻す。
- 最新コメントの意図どおり、backend 接頭辞ではなく `aws-cli` や `pdm` のようなツール名ベースで列挙できる設定に寄せる。
- 同じルールで列挙している他ツールにも同種の不整合がないか確認し、必要な例外条件を明確にする。

## 要件

### 機能要件

- `.github/renovate.json` の Patch 除外ルールが `aqua:aws/aws-cli` に対して正しく適用されること。
- 同一ルールに列挙している `flyctl`、`stripe-cli`、`usage`、`render-oss/cli`、`renovate`、`aws-cli`、`cosign`、`rust`、`pdm` にも意図どおり適用されること。
- 除外対象の列挙方法が `packageName` ベースになっており、manager / backend 接頭辞を書かずに管理できること。

### 非機能要件

- 既存の Renovate 設定の意図を崩さず、最小差分で修正すること。
- 設定変更後も `renovate-config-validator` を通過すること。
- ローカル検証の根拠を残し、Human Review 時点で修正妥当性を説明できること。

### 制約条件

- 変更対象は `dotfiles` リポジトリ内に限定する。
- GitHub token 非依存で再現できるローカル検証を優先する。

## 調査結果

- `renovate 42.70.3 --platform=local --dry-run=extract` で、`aqua:aws/aws-cli` は `depName = aqua:aws/aws-cli`、`packageName = aws/aws-cli` と抽出された。
- Renovate 公式ドキュメントでは、`matchPackageNames` は `packageName` を対象にし、exact / glob / regex での一致判定ができる。
- そのため `aws/aws-cli` のような完全一致名を毎回書かなくても、`/(^|\\/)aws-cli$/` のような末尾一致 regex で `aws-cli` ベースの列挙ができる。
- 同じ考え方で一致させられる対象:
  - `flyctl` -> `packageName = superfly/flyctl`
  - `stripe-cli` -> `packageName = stripe/stripe-cli`
  - `usage` -> `packageName = jdx/usage`
  - `renovate` -> `packageName = renovate`
  - `aws-cli` -> `packageName = aws/aws-cli`
  - `cosign` -> `packageName = sigstore/cosign`
  - `rust` -> `packageName = rust-lang/rust`
  - `pdm` -> `packageName = pdm-project/pdm`
- `render-oss/cli` は末尾の `cli` だけでマッチさせると `@taplo/cli` や `devcontainers/cli` にも広がるため、この 1 件だけは `render-oss/cli` の完全一致で扱うのが安全。
- `cosign` は `mise` では `packageName = sigstore/cosign` を持つ一方、`dot_config/brew/brew.json` を読む regex manager では `depName = cosign` だけが出て `packageName` が付与されない。そのため brew 側だけは狭い `matchDepNames` 補助ルールが必要。

## 実装計画

### 1. Patch 除外ルールの一致条件を修正する

- `.github/renovate.json` の対象ルールを `matchPackageNames` ベースにし、`aws-cli` や `pdm` などは末尾一致 regex で列挙する。
- `render-oss/cli` のように末尾名だけだと広すぎるものは完全一致にする。
- `cosign` の brew 抽出だけは `packageName` が無いため、`matchDepNames + matchManagers + matchFileNames` の狭い補助ルールで維持する。

### 2. 列挙済みツール全体への影響を確認する

- local dry-run extract のログを使い、列挙済み 9 件の `packageName` と rule 条件の対応を再確認する。
- `cosign` など manager をまたいで名前が出る依存が想定どおりかを確認し、必要な補助条件だけを追加する。

### 3. 設定変更後の検証を行う

- `renovate-config-validator --strict` で設定妥当性を確認する。
- `renovate --platform=local --dry-run=extract` を再実行し、抽出される `packageName` / `depName` と修正後ルールの対応関係を確認する。
- GitHub token がないため GitHub datasource の完全な lookup は限定されるが、少なくとも `npm:renovate` のような token 非依存な依存でルール適用確認が可能かを確認する。

## 変更対象ファイル

- `.github/renovate.json`

## 技術的課題と対応策

- GitHub datasource は token なしだと lookup が一部スキップされる。
  - 対応策: `extract` ログで `packageName` と rule 条件の対応を確認し、token 非依存な `npm:renovate` で lookup 実証を行う。
- `cli` のように末尾名だけだと別ツールにも広がる依存がある。
  - 対応策: `render-oss/cli` のような曖昧名は完全一致に切り替える。
- `cosign` の brew 抽出は `packageName` を持たない。
  - 対応策: `dot_config/brew/brew.json` に限定した `matchDepNames` 補助ルールでカバーする。

## テスト計画

- `env -i PATH=/Users/ryo./.local/share/mise/installs/node/22.19.0/bin:/usr/bin:/bin /Users/ryo./.local/share/mise/installs/node/22.19.0/bin/node /Users/ryo./.local/share/mise/installs/npm-renovate/42.70.3/node_modules/renovate/dist/config-validator.js --strict`
- `env -i HOME=/Users/ryo. LOG_LEVEL=debug PATH=/Users/ryo./.local/share/mise/installs/node/22.19.0/bin:/usr/bin:/bin /Users/ryo./.local/share/mise/installs/node/22.19.0/bin/node /Users/ryo./.local/share/mise/installs/npm-renovate/42.70.3/node_modules/renovate/dist/renovate.js --platform=local --dry-run=extract`
- 必要に応じて `--dry-run=lookup` を対象依存に絞って実行し、Patch 更新が除外されるログを確認する。

## リスクと未解決事項

- 末尾一致 regex を使う対象は、将来同じ末尾名の別 package が追加されると一緒にマッチする可能性がある。
- GitHub token なしでは GitHub datasource の完全な更新候補計算をローカルで再現しきれないため、検証は抽出結果と validator、`npm:renovate` の lookup 中心になる。
