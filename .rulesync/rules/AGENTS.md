---
root: true
targets:
  - codexcli
globs:
  - "**/*"
---

# Codex instructions

This repository manages personal dotfiles with mise.

## Session setup

At the start of each session, before editing or running checks, run
`bash scripts/ai-session-setup.sh` from the repository root. If the SessionStart
hook already completed it successfully in this session, do not run it again.
This installs the tools pinned in `mise.toml` and installs the Lefthook Git hooks,
including pre-commit checks. Do not skip setup just because SessionStart hooks
are unavailable in the current Codex environment.

If setup fails because network access or permissions are unavailable, report the
failure and the missing access; do not claim that setup or checks succeeded.

## Editing

- Edit source files in this repository, not deployed files under the home directory.
- Tools and their versions are managed in `mise.toml`.
- Write documentation under `docs/`; do not add links to `README.md`.
- This file is generated from `.rulesync/rules/AGENTS.md`. Edit the source and
  regenerate it with rulesync, keeping `AGENTS.md` in Git so a fresh Codex session
  can read the setup instructions before tools have been installed.
