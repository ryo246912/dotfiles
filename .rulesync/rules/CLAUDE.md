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

## This file itself

`CLAUDE.md` is generated from `.rulesync/rules/CLAUDE.md` by `rulesync generate` — edit the source, not this file. See `docs/rulesync.md`.

## More details

See `docs/**` and `README.md`.
