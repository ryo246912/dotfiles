# Repository instructions

This is a personal dotfiles repository managed with [mise](https://mise.jdx.dev/)'s `[dotfiles]` feature (`mise bootstrap dotfiles`).

## Critical Rule

- **Always edit source files in this repository**, never the deployed files (`~/.config/`, `~/.local/`, `~/`, etc.) — they get overwritten by `mise bootstrap dotfiles apply` on the next run.
- After editing, run `mise bootstrap dotfiles diff` to preview and `mise bootstrap dotfiles apply` to deploy.

## Tooling

Tools are managed by [mise](https://mise.jdx.dev/) (`mise.toml`); version upgrades are tracked via [Renovate](https://docs.renovatebot.com/).

## Homebrew 系パッケージの導入設定

- brew / brew-cask の導入設定を追加・変更する際は、まず mise bootstrap の `[bootstrap.packages]` で管理できるか検討する。対象の Mac で `mise bootstrap packages apply brew:<formula>` または `mise bootstrap packages apply brew-cask:<cask>` による導入を確認し、利用可能ならこの方式を優先する
- 過去のコメントや Cask の `auto_updates` 宣言だけを根拠に mise bootstrap が未対応と判断しない。実行環境がなく確認できない場合は未検証と明記する。直接の `brew install` を呼ぶ例外タスクは、現在の mise で導入できない具体的な理由を確認してから追加する

## This file itself

`CLAUDE.md` and `AGENTS.md` are generated from `.rulesync/rules/CLAUDE.md` by `rulesync generate` — edit the source, not these files. See `docs/rulesync.md`.

## Documentation

- Write docs under `docs/`. Do not add links to new docs (or any other new links) in `README.md`.

## More details

See `docs/**` and `README.md`.

## Codex Cloud での実装・PR・レビュー対応

- Codex Cloud で実装を依頼された場合は、検証・コミット・push・PR 作成までを自律的に行う。既存の作業 PR がある場合はその PR を更新する。ユーザーが作業範囲を制限した場合はその指示を優先する
- PR 作成後も、人間・bot のレビューコメントと CI を確認し、妥当な指摘や CI の失敗を修正してコミット・push する。この範囲の修正ごとに承認を求めない。採用しない指摘には理由をスレッドに返信する
- push 後は再びレビューと CI を確認する。依頼済みレビューが届き、未対応の指摘が無く、CI が通ったら結果と PR の URL を報告する。一定時間待っても届かないレビューは未着として報告する
- 確認には `gh pr view` / `gh pr checks` / `gh api` などを使い、待機中は適切な間隔で再確認する
- 作業範囲を大きく超える設計変更、矛盾・不明確な指摘、原因を特定できない反復的な失敗はユーザーに確認する。テストの無効化や force push で回避しない
- 認証・権限・ネットワークの制限で push・PR 作成・レビュー確認ができない場合は、可能な実装と検証を完了し、未完了の操作と理由を報告する。成功したと偽らない
