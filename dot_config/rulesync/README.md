# rulesync

この repo では、repo-local の [`.rulesync`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/.rulesync) と user-scope の [`dot_config/rulesync/exact_dot_rulesync`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/rulesync/exact_dot_rulesync) を rulesync 正本として扱います。

## ディレクトリ構成

```text
<repo root>/
├── .rulesync/
│   └── rules/
│       └── CLAUDE.md
└── dot_config/rulesync/
    ├── rulesync.jsonc
    ├── hooks/
    │   └── ai-rule-hook.md
    └── exact_dot_rulesync/
        ├── rules/
        ├── commands/
        ├── skills/
        └── mcp.json.tmpl
```

- `dot_config/rulesync/exact_dot_rulesync/` は chezmoi 経由で `~/.config/rulesync/.rulesync/` に配置される user-scope 正本です。
- `dot_config/rulesync/hooks/ai-rule-hook.md` は rulesync generate 対象ではありません。shared hook runner が直接読む prompt source です。

## 正本と生成物

- repo root `.rulesync/rules/CLAUDE.md`
  - repo root の `CLAUDE.md`
- `dot_config/rulesync/exact_dot_rulesync/rules/CLAUDE.md`
  - `~/.claude/CLAUDE.md`
- `dot_config/rulesync/exact_dot_rulesync/rules/CODEX.md`
  - `~/.codex/AGENTS.md`
- `dot_config/rulesync/exact_dot_rulesync/rules/GEMINI.md`
  - `~/.gemini/GEMINI.md`
- `dot_config/rulesync/exact_dot_rulesync/commands/*.md`
  - Gemini CLI custom commands
- `dot_config/rulesync/exact_dot_rulesync/skills/*`
  - Claude / Codex skills
- `dot_config/rulesync/exact_dot_rulesync/mcp.json.tmpl`
  - Claude / Codex / Gemini / Copilot CLI 向け MCP 正本

## hooks の扱い

rulesync は現時点で hooks 自体を generate しないため、hook 定義ファイルは tracked file として別管理します。

- Claude: [`dot_claude/settings.json`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_claude/settings.json)
- Codex: [`dot_codex/config.toml`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_codex/config.toml), [`dot_codex/hooks.json`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_codex/hooks.json)
- Gemini: native hook は 2026-04-09 時点の公式 docs で確認できていないため、[`dot_config/rulesync/exact_dot_rulesync/commands/ai-rule-hook.md`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/rulesync/exact_dot_rulesync/commands/ai-rule-hook.md) を手動 fallback として使います

shared runner 本体は [`dot_config/devcontainer/scripts/executable_ai-rule-hook.sh`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/devcontainer/scripts/executable_ai-rule-hook.sh) を正本として扱います。devcontainer でも同じ path を使うため、[`dot_config/devcontainer/devcontainer.json`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/devcontainer/devcontainer.json) で `~/.config/devcontainer/scripts` と `~/.config/rulesync` を mount します。

## 更新フロー

1. repo 内の `.rulesync/` または `dot_config/rulesync/exact_dot_rulesync/` / `dot_config/rulesync/hooks/` を編集する
2. `chezmoi apply` で `~/.config/rulesync` と各 tracked 設定を反映する
3. `mise run rulesync-generate` で生成対象を更新する
4. 必要に応じて以下を確認する
   - `git diff -- dot_claude dot_codex dot_gemini dot_config/devcontainer dot_config/rulesync`
   - `bash -n dot_config/devcontainer/scripts/executable_ai-rule-hook.sh`
   - `shellcheck dot_config/devcontainer/scripts/executable_ai-rule-hook.sh`

## Gemini fallback

Gemini CLI では native hook が見当たらないため、自動実行はしていません。会話が消える前にルール候補を確認したい場合は、rulesync から生成される `ai-rule-hook` command を `/clear` や `/compress` の前に手動実行してください。
