---
root: true
targets:
  - claudecode
globs:
  - "**/*"
---

# CLAUDE.md

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

`CLAUDE.md` is generated from `.rulesync/rules/CLAUDE.md` by `rulesync generate` — edit the source, not this file. See `docs/rulesync.md`.

## Documentation

- Write docs under `docs/`. Do not add links to new docs (or any other new links) in `README.md`.

## More details

See `docs/**` and `README.md`.
