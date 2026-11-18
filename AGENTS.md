# リポジトリの作業ルール

このリポジトリは、[mise](https://mise.jdx.dev/) の `[dotfiles]` 機能（`mise bootstrap dotfiles`）で管理する個人用 dotfiles です。

## 必ず守るルール

- **必ずこのリポジトリ内のソースファイルを編集する**。配置済みのファイル（`~/.config/`、`~/.local/`、`~/` など）は直接編集しない。次回の `mise bootstrap dotfiles apply` で上書きされるため。
- 編集後は `mise bootstrap dotfiles diff` で差分を確認し、`mise bootstrap dotfiles apply` で配置する。

## ツール管理

ツールは [mise](https://mise.jdx.dev/)（`mise.toml`）で管理し、バージョン更新は [Renovate](https://docs.renovatebot.com/) で追跡します。

## Homebrew 系パッケージの導入設定

- brew / brew-cask の導入設定を追加・変更する際は、まず mise bootstrap の `[bootstrap.packages]` で管理できるか検討する。対象の Mac で `mise bootstrap packages apply brew:<formula>` または `mise bootstrap packages apply brew-cask:<cask>` による導入を確認し、利用可能ならこの方式を優先する
- 過去のコメントや Cask の `auto_updates` 宣言だけを根拠に mise bootstrap が未対応と判断しない。実行環境がなく確認できない場合は未検証と明記する。直接の `brew install` を呼ぶ例外タスクは、現在の mise で導入できない具体的な理由を確認してから追加する

## このファイルの更新方法

`CLAUDE.md` と `AGENTS.md` は、`.rulesync/rules/CLAUDE.md` から `rulesync generate` で生成します。生成ファイルを直接編集せず、ソースを編集してください。詳細は `docs/rulesync.md` を参照してください。

## ドキュメント

- ドキュメントは `docs/` 配下に作成する。`README.md` には、新しいドキュメントへのリンクや、その他の新しいリンクを追加しない。

## 詳細情報

`docs/**` と `README.md` を参照してください。

## Codex Cloud での実装・PR・レビュー対応

- Codex Cloud で実装を依頼された場合は、検証・コミット・push・PR 作成までを自律的に行う。既存の作業 PR がある場合はその PR を更新する。ユーザーが作業範囲を制限した場合はその指示を優先する
- PR を作成した時点で作業を終えず、人間・bot のレビュー指摘と CI ステータスを自律的に確認する。妥当な指摘は修正・検証してコミット・push し、スレッドに対応内容を返信する。採用しない指摘には理由を返信する。この範囲の修正ごとに承認を求めない
- CI が失敗したらログを確認して原因を調査する。今回の変更に起因する失敗と、ユーザーが対応を依頼した失敗は、自律的に修正・検証・コミット・push する。base 由来の既存の失敗も今回の作業範囲に含まれる場合は修正し、「既存のエラー」と報告するだけで対応を終えない
- 作業範囲外の既存の失敗、外部サービスの障害、調査しても原因を特定できない反復的な失敗は、ログなどの根拠と未完了の内容を報告する。同じ失敗の修正や再実行を無限に繰り返さず、対応可能な指摘への処理を終えたうえで終了する
- 修正を push するたびにレビュー指摘と CI ステータスを再確認し、新たな指摘・失敗があれば対応を繰り返す。依頼済みレビューが届き、未対応の指摘が無く、CI が通ったら結果と PR の URL を報告する。一定時間待っても届かないレビューは未着として報告する
- 確認には `gh pr view` / `gh pr checks` / `gh api` などを使い、待機中は適切な間隔で再確認する
- 作業範囲を大きく超える設計変更、矛盾・不明確な指摘、原因を特定できない反復的な失敗はユーザーに確認する。テストの無効化や force push で回避しない
- 認証・権限・ネットワークの制限で push・PR 作成・レビュー確認ができない場合は、可能な実装と検証を完了し、未完了の操作と理由を報告する。成功したと偽らない
