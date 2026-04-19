# DOTFILE-13 AWS 補助ツールのメモ追加

## 概要

- `taws` と `aws-vault` の便利な設定・使い方を `dotfiles` リポジトリ内のメモとして追加する
- `README.md` / `setup.md` / `dot_config/navi/cheats/aws.cheat.md` から新規メモへ到達できるようにする
- 提供された作業コピーには過去 workpad で言及されていた追加ファイルが存在しないため、このコピー上でドキュメントを再構築する

## 要件

### 機能要件

- `not_config/memo/taws.md` を追加し、導入方法、前提設定、`--readonly`、SSO、`login_session`、role assumption、shell completion、repo 文脈での使い分けをまとめる
- `not_config/memo/aws-vault.md` を追加し、backend、`add` / `exec` / `login` / `list` / `remove` / `clear`、MFA、role、SSO、`--server`、abandoned caveat をまとめる
- `README.md` と `setup.md` から両メモへ遷移できるようにする
- `dot_config/navi/cheats/aws.cheat.md` には本文の重複を増やしすぎず、高頻度コマンドのみを追記する

### 非機能要件

- 技術的な記述は upstream の一次情報に寄せる
- 既存リポジトリのメモ用途に合わせ、実運用で使う順序が追いやすい構成にする
- `taws` のリリース運用が動いているため、本文ではバージョン固定を避ける

### 制約条件

- 実装対象は `dotfiles` サブリポジトリのみ
- 秘密情報や実 AWS 環境を必要とする検証は行わず、ドキュメント整合性の確認までをこのセッションの品質バーにする
- 既存の AWS 関連設定 (`AWS_CLI_AUTO_PROMPT=on-partial`、`aws` cheat など) と矛盾しない説明にする

## 実装計画

### 1. 現状整理と計画同期

- 既存 workpad を、この作業コピーの実態に合わせて再同期する
- `git fetch origin main --prune` の結果と、現時点で `taws` / `aws-vault` メモが存在しないことを記録する
- 参照する upstream ドキュメントを `taws` README、`aws-vault` README / `USAGE.md` に限定する

### 2. AWS 補助ツールのメモ追加

- `not_config/memo/taws.md` に、導入・前提・起動例・認証パターン・便利設定・repo 向け推奨を追加する
- `not_config/memo/aws-vault.md` に、導入・backend・主要コマンド・MFA / role / SSO・`--server`・注意点を追加する
- `taws` と `aws-vault` の役割差分を両メモのどちらか一方に閉じず、読んだ時点で判断できるようにする

### 3. 導線とチートシートの更新

- `README.md` に AWS 補助ツールメモへの導線を追加する
- `setup.md` に確認用チェックリストとして両メモへのリンクを追加する
- `dot_config/navi/cheats/aws.cheat.md` に `taws` / `aws-vault` の高頻度コマンドだけを追加する

### 4. 検証と handoff

- `rg` で導線とキーワードを確認する
- `sed` で追加メモと導線の文面をレビューする
- `git diff --check` で差分の体裁崩れがないことを確認する
- 可能なら commit / push / draft PR / Linear 更新まで完了する

## 技術的課題と対応策

- `taws` は README ベースで仕様が増えているため、記述対象は README に明示されている機能に絞る
- `aws-vault` は upstream が abandoned と明言しているため、導入案内には caveat と代替 fork の存在を明記する
- このチケットは過去 workpad と現在の作業コピーがずれているため、workpad では再実装であることを明示して整合性を回復する

## テスト計画

- `rg -n "taws|aws-vault" README.md setup.md not_config/memo dot_config/navi/cheats/aws.cheat.md`
- `rg -n "aws sso|AWS_PROFILE|AWS_CLI_AUTO_PROMPT|aws-vault|taws" dot_config not_config README.md setup.md`
- `sed -n '1,240p' plan/dotfile-13.md`
- `sed -n '1,240p' not_config/memo/taws.md`
- `sed -n '1,260p' not_config/memo/aws-vault.md`
- `sed -n '1,80p' README.md`
- `sed -n '1,260p' setup.md`
- `sed -n '1,120p' dot_config/navi/cheats/aws.cheat.md`
- `git diff --check`

## リスクと未確定事項

- `taws` / `aws-vault` ともに実際の AWS 認証まではこのセッションで試せないため、動作検証は upstream ドキュメントと repo 文脈の整合性確認に留まる
- `gh` 認証や push 権限が不足している場合は PR 作成まで完了できない可能性がある

## 参考資料

- `taws` README: https://github.com/huseyinbabal/taws
- `aws-vault` README: https://github.com/99designs/aws-vault
- `aws-vault` USAGE: https://github.com/99designs/aws-vault/blob/master/USAGE.md
