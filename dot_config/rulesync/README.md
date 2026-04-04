# rulesync

repo root の `.rulesync/` と `dot_config/rulesync/` を、この repo における AI rule / skill / command の正本として扱います。

## ディレクトリ構成

```text
<repo root>/
├── rulesync.jsonc                    # repo root CLAUDE.md 用
├── .rulesync/
│   └── rules/
│       └── CLAUDE.md
├── dot_config/rulesync/
│   ├── README.md
│   ├── rulesync.jsonc               # user-scope source
│   ├── rulesync.lock                # curated skill の lockfile
│   ├── .gitignore                   # .curated / local override 用
│   ├── scripts/
│   │   └── executable_generate-user.sh
│   └── .rulesync/
│       ├── rules/
│       │   ├── CLAUDE.md
│       │   ├── CODEX.md
│       │   ├── GEMINI.md
│       │   └── COPILOT.md
│       ├── skills/
│       │   ├── <local-skill>/SKILL.md
│       │   └── .curated/<remote-skill>/SKILL.md
│       └── commands/
│           └── <command>.md
├── dot_claude/
├── dot_codex/
├── dot_gemini/
└── dot_copilot/
```

## 管理対象

- repo root `.rulesync/rules/CLAUDE.md`
  - repo root `CLAUDE.md`
- `dot_config/rulesync/.rulesync/rules/CLAUDE.md`
  - `dot_claude/CLAUDE.md`
- `dot_config/rulesync/.rulesync/rules/CODEX.md`
  - `dot_codex/AGENTS.md`
- `dot_config/rulesync/.rulesync/rules/GEMINI.md`
  - `dot_gemini/GEMINI.md`
- `dot_config/rulesync/.rulesync/rules/COPILOT.md`
  - `dot_copilot/copilot-instructions.md`
- `dot_config/rulesync/.rulesync/skills/*`
  - `dot_claude/skills/*`
  - `dot_codex/skills/*`
  - `dot_gemini/skills/*`
- `dot_config/rulesync/.rulesync/commands/*`
  - `dot_claude/commands/*`
  - `dot_codex/prompts/*`（rulesync simulated command）
  - `dot_gemini/commands/*`

以下は rulesync 管理対象外です。

- `dot_claude/settings.json`
- `dot_gemini/settings.json`
- `dot_config/claude/*.json`

## curated skill の扱い

`dot_config/rulesync/rulesync.jsonc` の `sources` で外部 skill を宣言し、`rulesync install` で `.rulesync/skills/.curated/` に取得します。

- 公式 skill
  - `anthropics/skills` の `skill-creator`
- review 系 OSS skill
  - `antoniocascais/claude-code-knowledge` の `pr-review`
  - `antoniocascais/claude-code-knowledge` の `workflow-review`
  - `antoniocascais/claude-code-knowledge` の `test-quality`

`.curated/` は commit しません。再現性は `dot_config/rulesync/rulesync.lock` で担保します。

## install / generate

`rulesync` は repo の mise 管理に追加済みです。

```sh
mise install
```

### repo root の `CLAUDE.md` を更新する

```sh
mise run rulesync-generate-local
```

### curated skill を解決する

```sh
mise run rulesync-install-user
```

### user-scope の tracked output を更新する

```sh
mise run rulesync-generate-user
```

この task は以下をまとめて行います。

1. `dot_config/rulesync/rulesync.jsonc` の `sources` を `rulesync install` で解決する
2. temp HOME に `rulesync generate --global --simulate-commands --simulate-skills` を実行する
3. 生成結果を repo の `dot_claude` / `dot_codex` / `dot_gemini` / `dot_copilot` へ同期する

### まとめて更新する

```sh
mise run rulesync-generate
```

## 通常の更新フロー

1. `.rulesync/` または `dot_config/rulesync/.rulesync/` の source を編集する
2. curated source を更新したい場合は `mise run rulesync-install-user` を実行する
3. `mise run rulesync-generate` を実行する
4. `git diff -- CLAUDE.md dot_claude dot_codex dot_gemini dot_copilot dot_config/rulesync` で差分を確認する
5. 必要なら `mise run lint-toml` と `mise run lint-other` を実行する
6. `chezmoi diff` / `chezmoi apply` でホームディレクトリへ反映する

`dot_claude` / `dot_codex` / `dot_gemini` / `dot_copilot` は chezmoi source そのものなので、以前の `chezmoi re-add` は不要です。

## devcontainer との関係

`dot_config/devcontainer/devcontainer.json` はホストの `~/.claude` `~/.codex` `~/.gemini` を bind mount しています。つまり、

1. repo で `mise run rulesync-generate` を実行する
2. `chezmoi apply` で `dot_claude` / `dot_codex` / `dot_gemini` / `dot_copilot` をホームへ反映する

この 2 段階で、devcontainer からも同じ skill / command catalog を利用できます。

## import の扱い

通常運用では import は不要です。既存出力から source を再構築したいときだけ temp ディレクトリで検証し、必要箇所だけを `.rulesync/` へ戻してください。

## 注意点

- `dot_config/rulesync/.rulesync/skills` の local skill が最優先です。curated skill と同名なら local が勝ちます。
- `plan:implement` / `plan:search` の command source は repo ではそのまま管理しています。rulesync generate の結果が利用環境で成立するかは、tracked output の diff で確認してください。
- Codex 向け commands / skills は simulated feature なので、Claude 向け出力と構造が異なる場合があります。
