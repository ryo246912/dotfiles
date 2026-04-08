# rulesync

repo root の `.rulesync/` と `dot_config/rulesync/` を、この repo における AI rule / skill / command の正本ディレクトリとして扱います。

## ディレクトリ構成

```text
<repo root>/
├── rulesync.jsonc          # project-local config（repo root CLAUDE.md 専用）
├── .rulesync/
│   └── rules/
│       └── CLAUDE.md       # repo root CLAUDE.md の source
└── dot_config/rulesync/
    ├── README.md
    ├── rulesync.jsonc      # global: true（user-scope 全体）
    └── .rulesync/
        ├── rules/
        │   ├── CLAUDE.md   # ~/.claude/CLAUDE.md の source
        │   ├── GEMINI.md   # ~/.gemini/GEMINI.md の source
        │   └── COPILOT.md  # ~/.github/copilot-instructions.md の source
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
  - `~/.copilot/copilot-instructions.md`（generate 後に repo の `.github/copilot-instructions.md` へ内容を反映）
- `dot_config/rulesync/.rulesync/skills/*`
  - `dot_claude/skills/*`
  - `dot_codex/skills/*`（generate 後に `chezmoi re-add`）
- `dot_config/rulesync/.rulesync/commands/*`
  - `dot_gemini/commands/*`（generate 後に `chezmoi re-add`）

以下は rulesync 管理対象外です。

- `dot_claude/settings.json`
- `dot_codex/config.toml`
- `dot_gemini/settings.json`
- `.github/hooks/*.json`
- `dot_config/claude/*.json`

## インストール

`rulesync` は repo の mise 管理に追加してあります。

```sh
mise install
```

個別に入れる場合は以下でも構いません。

```sh
mise install github:dyoshikawa/rulesync@7.23.0
```

## generate

### repo root の CLAUDE.md だけ更新する

```sh
mise run rulesync-generate-local
# または直接
rulesync generate
```

### user-scope（Claude / Codex / Gemini / Copilot）を更新する

```sh
mise run rulesync-generate-user
# または直接
(cd ~/.config/rulesync && rulesync generate)
```

この generate は `~/.claude`、`~/.codex`、`~/.gemini`、`~/.copilot` へ直接書き出します。
その後、chezmoi re-add や repo copy への反映を行ってください。

```sh
chezmoi re-add ~/.claude/CLAUDE.md ~/.claude/skills ~/.codex/AGENTS.md ~/.codex/skills ~/.gemini/GEMINI.md ~/.gemini/commands
cp ~/.copilot/copilot-instructions.md <repo root>/.github/copilot-instructions.md
```

Copilot の notification hook JSON（`.github/hooks/*.json`）、GitHub 側で読む `.github/copilot-instructions.md`、Codex の `dot_codex/config.toml` は rulesync ではなく repo で直接管理します。

### 両方まとめて実行する

```sh
mise run rulesync-generate
```

## 通常の更新フロー

1. `<repo root>/.rulesync/` または `dot_config/rulesync/.rulesync/` 配下の source を編集する
2. generate を実行する
   - repo root CLAUDE.md のみ: `mise run rulesync-generate-local`
   - user-scope のみ: `mise run rulesync-generate-user`
   - 両方: `mise run rulesync-generate`
3. user-scope を変更した場合は `chezmoi re-add` を実行する
4. `git diff -- CLAUDE.md dot_claude dot_codex dot_gemini dot_config/rulesync .github` で差分を確認する
5. 必要なら `mise run lint-toml` と `mise run lint-other` を実行する

## import のやり方

通常運用では import は不要です。既存出力から source を再構築したいときだけ使います。

この repo では、2026-04-05 に `rulesync 7.23.0` で temp HOME を使った generate 検証を行っています。`copilot` target 名が一致していれば `~/.codex` と `~/.github` への generate が成功するため、出力確認は temp HOME で行い、必要な差分だけを repo に反映してください。

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

temp HOME generate の正本は以下です。

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
- `dot_config/rulesync/rulesync.jsonc` の Copilot target は `copilot` が正です。`copilotonvs` のままだと `.github/copilot-instructions.md` が生成されません。
- `geminicli` generate の結果は rulesync 側の都合で `# Additional Conventions Beyond the Built-in Functions` の導入文が先頭に付きます。
