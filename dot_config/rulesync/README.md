# rulesync

repo root の `.rulesync/` と `dot_config/rulesync/` を、この repo における AI rule / MCP / skill / command の正本ディレクトリとして扱います。

## ディレクトリ構成

```text
<repo root>/
├── rulesync.jsonc          # project-local config（repo root CLAUDE.md）
├── .rulesync/
│   └── rules/
│       └── CLAUDE.md       # repo root CLAUDE.md の source
└── dot_config/rulesync/
    ├── README.md
    ├── rulesync.jsonc      # global: true（Claude / Codex / Gemini の user-scope）
    └── .rulesync/
        ├── mcp.json        # ~/.copilot/mcp-config.json の source（stdio subset）
        ├── rules/
        │   ├── CLAUDE.md   # ~/.claude/CLAUDE.md の source
        │   ├── GEMINI.md   # ~/.gemini/GEMINI.md の source
        │   └── COPILOT.md  # ~/.copilot/copilot-instructions.md の source
        ├── skills/
        │   └── <skill>/SKILL.md
        └── commands/
            └── <command>.md
```

## 管理対象

- `<repo root>/.rulesync/rules/CLAUDE.md`
  - repo root の `CLAUDE.md`
- `dot_config/rulesync/.rulesync/rules/CLAUDE.md`
  - `dot_claude/CLAUDE.md`（generate 後に `chezmoi re-add`）
- `dot_config/rulesync/.rulesync/rules/CODEX.md`
  - `~/.codex/AGENTS.md`（generate 後に `chezmoi re-add`）
- `dot_config/rulesync/.rulesync/rules/GEMINI.md`
  - `dot_gemini/GEMINI.md`（generate 後に `chezmoi re-add`）
- `dot_config/rulesync/.rulesync/rules/COPILOT.md`
  - `dot_copilot/copilot-instructions.md`（`~/.copilot/copilot-instructions.md` を generate 後に `chezmoi re-add`）
- `dot_config/rulesync/.rulesync/mcp.json`
  - `dot_copilot/mcp-config.json`（`~/.copilot/mcp-config.json` を generate 後に `chezmoi re-add`）
- `dot_config/rulesync/.rulesync/skills/*`
  - `dot_claude/skills/*`
  - `dot_codex/skills/*`（generate 後に `chezmoi re-add`）
- `dot_config/rulesync/.rulesync/commands/*`
  - `dot_gemini/commands/*`（generate 後に `chezmoi re-add`）

以下は rulesync 管理対象外です。

- `dot_claude/settings.json`
- `dot_gemini/settings.json`
- `dot_config/claude/*.json`

## インストール

`rulesync` は repo の mise 管理に追加してあります。

```sh
mise install
```

個別に入れる場合は以下でも構いません。

```sh
mise install npm:rulesync@7.23.0
```

## generate

### repo root の CLAUDE.md だけ更新する

```sh
mise run rulesync-generate-local
# または直接
rulesync generate
```

### user-scope（Claude / Codex / Gemini）を更新する

```sh
mise run rulesync-generate-user
# または直接
(cd ~/.config/rulesync && rulesync generate)
```

### user-scope の Copilot instructions を更新する

```sh
mise run rulesync-generate-user-copilot
# または直接
(cd ~/.config/rulesync && rulesync generate --targets copilot --features rules --global)
```

### user-scope の Copilot CLI MCP を更新する

```sh
mise run rulesync-generate-mcp-copilotcli
# または直接
(cd ~/.config/rulesync && rulesync generate --targets copilotcli --features mcp --global)
```

### まとめて実行する

```sh
mise run rulesync-generate
```

user-scope を更新した場合は、その後 `chezmoi re-add` で chezmoi source へ反映してください。

```sh
chezmoi re-add ~/.claude/CLAUDE.md ~/.claude/skills ~/.codex/AGENTS.md ~/.codex/skills ~/.gemini/GEMINI.md ~/.gemini/commands ~/.copilot/copilot-instructions.md ~/.copilot/mcp-config.json
```

## 通常の更新フロー

1. `<repo root>/.rulesync/` または `dot_config/rulesync/.rulesync/` 配下の source を編集する
2. generate を実行する
   - repo root CLAUDE.md: `mise run rulesync-generate-local`
   - user-scope Claude / Codex / Gemini: `mise run rulesync-generate-user`
   - user-scope Copilot instructions: `mise run rulesync-generate-user-copilot`
   - user-scope Copilot CLI MCP: `mise run rulesync-generate-mcp-copilotcli`
   - 全部まとめて: `mise run rulesync-generate`
3. user-scope を変更した場合は `chezmoi re-add` を実行する
4. `git diff -- CLAUDE.md dot_claude dot_codex dot_copilot dot_gemini dot_config/rulesync` で差分を確認する
5. 必要なら `mise run lint-toml` と `mise run lint-other` を実行する

## import のやり方

通常運用では import は不要です。既存出力から source を再構築したいときだけ使います。

この repo では、2026-03-11 に `rulesync 7.15.2` で temp ディレクトリを使った import 検証を行っています。`rulesync init` が作るデフォルト source も同時に生成されるため、import 結果はそのまま上書きせず、必要な差分だけを `.rulesync` に取り込んでください。

### repo root `CLAUDE.md`

```sh
tmp_dir="$(mktemp -d dot_config/rulesync/.tmp/import-root.XXXXXX)"
cp CLAUDE.md "$tmp_dir/CLAUDE.md"
(
  cd "$tmp_dir"
  rulesync init
  rm -f .rulesync/rules/overview.md
  rulesync import -t claudecode -f rules
)
```

生成された `$tmp_dir/.rulesync/rules/CLAUDE.md` を `<repo root>/.rulesync/rules/CLAUDE.md` に反映します。

import 直後の frontmatter は `targets: ["*"]` になるため、この repo へ戻すときは `targets: ["claudecode"]` に戻します。

### `dot_claude/CLAUDE.md` / skills / `dot_codex/skills`

`rulesync 7.15.2` では temp HOME 経由の import が安定しないため、以下を正本として扱ってください。

- `dot_config/rulesync/.rulesync/rules/CLAUDE.md`
- `dot_config/rulesync/.rulesync/skills/*`

どうしても再 bootstrap が必要な場合は、temp project で import 結果を確認したうえで、必要箇所だけを手動で source に寄せます。shared skills は Claude/Codex の文言差分を吸収するため、反映前に以下も確認してください。

- `targets` が `claudecode` / `codexcli` になっていること
- `Claude Code` / `Codex` のような tool 固有名を shared wording に直していること

### Gemini rules / commands

```sh
tmp_home="$(mktemp -d dot_config/rulesync/.tmp/import-gemini-home.XXXXXX)"
tmp_work="$(mktemp -d dot_config/rulesync/.tmp/import-gemini-work.XXXXXX)"
ln -s "$PWD/dot_gemini" "$tmp_home/.gemini"
(
  cd "$tmp_work"
  rulesync init
  rulesync import -g -t geminicli -f rules,commands
)
```

import 後は以下の正規化を行ってください。

- `overview.md` を `GEMINI.md` に寄せる
- command source を `*.md` にリネームする
- `targets` や説明文の frontmatter を既存 source に合わせて整える

## 注意点

- `dot_config/rulesync/` の user-scope generate は shared source です。`dot_claude/skills` と `dot_codex/skills` は同じ本文になります。
- `geminicli` generate の結果は rulesync 側の都合で `# Additional Conventions Beyond the Built-in Functions` の導入文が先頭に付きます。
- `copilotcli` の MCP は 2026-03-31 時点で `rulesync 7.23.0` と `7.25.0` のどちらでも `command` を持つ stdio server のみ扱えます。`dot_config/rulesync/.rulesync/mcp.json` にはその subset だけを置いています。
