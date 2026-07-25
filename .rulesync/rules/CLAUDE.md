---
root: true
targets:
  - claudecode
globs:
  - "**/*"
---

# CLAUDE.md

This is a personal dotfiles repository managed with [chezmoi](https://github.com/twpayne/chezmoi).

## Critical Rule

- **Always edit source files in this repository**, never the deployed files (`~/.config/`, `~/.local/`, `~/`, etc.) — they get overwritten by chezmoi on the next apply.
- After editing, run `chezmoi diff` to preview and `chezmoi apply` to deploy.

## Tooling

Tools are managed by [mise](https://mise.jdx.dev/) (`mise.toml`); version upgrades are tracked via [Renovate](https://docs.renovatebot.com/).

## This file itself

`CLAUDE.md` is generated from `.rulesync/rules/CLAUDE.md` by `rulesync generate` — edit the source, not this file. See `docs/rulesync.md`.

## More details

See `docs/**` and `README.md`.
