# rulesync

repo root の `.rulesync/` と `dot_config/rulesync/.rulesync/` を、この repo における AI rule / skill / command の正本ディレクトリとして扱います。

## ディレクトリ構成

```text
<repo root>/
├── rulesync.jsonc                  # repo local CLAUDE.md 用
├── .rulesync/
│   └── rules/
│       └── CLAUDE.md               # repo root CLAUDE.md の source
└── dot_config/rulesync/
    ├── README.md
    ├── rulesync.jsonc              # global: Claude / Codex / Gemini
    └── .rulesync/
        ├── rules/
        │   ├── CLAUDE.md
        │   ├── CODEX.md
        │   ├── GEMINI.md
        │   └── COPILOT.md
        ├── skills/
        │   └── <skill>/SKILL.md
        └── commands/
            └── <command>.md
```

## 管理対象

- `<repo root>/.rulesync/rules/CLAUDE.md`
  - repo root の `CLAUDE.md`
- `dot_config/rulesync/.rulesync/rules/CLAUDE.md`
  - `~/.claude/CLAUDE.md`
- `dot_config/rulesync/.rulesync/rules/CODEX.md`
  - `~/.codex/AGENTS.md`
- `dot_config/rulesync/.rulesync/rules/GEMINI.md`
  - `~/.gemini/GEMINI.md`
- `dot_config/rulesync/.rulesync/rules/COPILOT.md`
  - `~/.copilot/copilot-instructions.md`
- `dot_config/rulesync/.rulesync/skills/*`
  - `~/.claude/skills/*`
  - `~/.codex/skills/*`
- `dot_config/rulesync/.rulesync/commands/*`
  - `~/.gemini/commands/*.toml`

以下は rulesync 管理対象外です。

- `dot_claude/settings.json`
- `dot_gemini/settings.json`
- `dot_config/claude/*.json`

## CodeRabbit 運用方針

- 実装や設定変更のあとに、自律レビューを commit hook ではなく CodeRabbit CLI で回します。
- 既定コマンドは `coderabbit review --prompt-only --type uncommitted` です。
- Claude Code は plugin が使える場合 `/coderabbit:review` を優先します。
- `dot_config/rulesync/.rulesync/skills/coderabbit/SKILL.md` と `dot_config/rulesync/.rulesync/commands/coderabbit.md` は、CodeRabbit 公式 `code-review` skill 相当の review loop に合わせています。
- 既存 PR コメント修正は `review-fix` に分離するため、CodeRabbit 公式 `autofix` 相当の別 skill は追加していません。

## インストール

`rulesync` は repo の mise 管理に追加してあります。

```sh
mise install
```

個別に入れる場合は以下でも構いません。

```sh
mise install github:dyoshikawa/rulesync@7.27.1
```

## generate

### repo root の CLAUDE.md だけ更新する

```sh
mise run rulesync-generate-local
# または直接
rulesync generate
```

### user-scope の Claude / Codex / Gemini を更新する

```sh
mise run rulesync-generate-user-main
# または直接
(cd ~/.config/rulesync && rulesync generate)
```

### user-scope の Copilot instructions を更新する

```sh
mise run rulesync-generate-user-copilot
# または直接
(cd ~/.config/rulesync && rulesync generate -g -t copilot -f rules)
```

### user-scope をまとめて更新する

```sh
mise run rulesync-generate-user
```

この generate は `~/.claude`、`~/.codex`、`~/.gemini`、`~/.copilot` へ直接書き出します。
その後、chezmoi re-add で source へ反映してください。

```sh
chezmoi re-add ~/.claude/CLAUDE.md ~/.claude/skills ~/.codex/AGENTS.md ~/.codex/skills ~/.gemini/GEMINI.md ~/.gemini/commands ~/.copilot/copilot-instructions.md
```

### repo local + user-scope をまとめて更新する

```sh
mise run rulesync-generate
```

## 通常の更新フロー

1. `<repo root>/.rulesync/` または `dot_config/rulesync/.rulesync/` 配下の source を編集する
2. generate を実行する
   - repo local のみ: `mise run rulesync-generate-local`
   - Claude / Codex / Gemini: `mise run rulesync-generate-user-main`
   - Copilot: `mise run rulesync-generate-user-copilot`
   - user-scope 全体: `mise run rulesync-generate-user`
   - 全部まとめて: `mise run rulesync-generate`
3. user-scope を変更した場合は `chezmoi re-add` を実行する
4. `git diff -- CLAUDE.md dot_claude dot_codex dot_gemini dot_config/rulesync` で差分を確認する
5. 必要なら `mise run lint-toml` と `mise run lint-other` を実行する

## 検証

```sh
rulesync generate
(cd dot_config/rulesync && rulesync generate --dry-run)
(cd dot_config/rulesync && rulesync generate --dry-run -g -t copilot -f rules)
coderabbit review --help
coderabbit auth status
```

## 注意点

- `dot_config/rulesync/` の user-scope source は shared です。Claude / Codex の `coderabbit` skill は同一本文になります。
- `geminicli` generate の結果は rulesync 側の都合で command が `*.toml` として出力されます。
- `copilot` target は rules-only です。`rulesync 7.27.1` 時点では同ディレクトリにある既定 `rulesync.jsonc` の影響を受けやすいため、Copilot 側は `rulesync generate -g -t copilot -f rules` の明示指定で更新してください。
