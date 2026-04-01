# RTK 導入メモ

この repo では [rtk-ai/rtk](https://github.com/rtk-ai/rtk) を、Claude Code / Codex / Gemini CLI / GitHub Copilot で使えるようにしています。

## 目的

- shell command の出力を `rtk` 経由で圧縮し、LLM に渡るトークン量を削減する
- `chezmoi` / `rulesync` の source-of-truth を崩さずに、repo 内だけで設定差分を再現できるようにする
- 4 ツールの導入手順と制約を 1 か所で確認できるようにする

## 管理しているファイル

| tool           | repo 内の主なファイル                                                                                      | 備考                                                                    |
| -------------- | ---------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Claude Code    | `dot_claude/settings.json`, `dot_claude/hooks/rtk-rewrite.sh`, `dot_claude/CLAUDE.md`, `dot_claude/RTK.md` | Bash の `PreToolUse` hook で自動書き換え                                |
| Codex          | `dot_codex/AGENTS.md`, `dot_codex/RTK.md`                                                                  | hook ではなく prompt-level guidance                                     |
| Gemini CLI     | `dot_gemini/settings.json`, `dot_gemini/hooks/rtk-hook-gemini.sh`, `dot_gemini/GEMINI.md`                  | `BeforeTool` hook で自動書き換え                                        |
| GitHub Copilot | `.github/hooks/rtk-rewrite.json`, `.github/copilot-instructions.md`                                        | VS Code Copilot Chat は自動書き換え、Copilot CLI は suggestion fallback |

## インストール

`mise` に `github:rtk-ai/rtk = "0.34.2"` を追加してあります。

```sh
mise install github:rtk-ai/rtk
rtk --version
rtk gain
```

`rtk gain` が失敗する場合は、別 project の `rtk` が入っている可能性があります。`which rtk` で binary を確認してください。

## 各ツールでの使い方

### Claude Code

- `dot_claude/settings.json` の `PreToolUse` が `~/.claude/hooks/rtk-rewrite.sh` を呼びます。
- 通常の Bash command は hook 側で `rtk ...` に書き換えられる前提です。
- `Read` / `Grep` / `Glob` など built-in tool は hook を通らないため、圧縮出力が必要なときは Bash で `cat`, `head`, `tail`, `rg`, `grep`, `find` を使うか、`rtk read`, `rtk grep`, `rtk find` を直接実行してください。
- meta command は `rtk gain`, `rtk gain --history`, `rtk discover`, `rtk proxy <cmd>` をそのまま使えます。

### Codex

- `dot_codex/AGENTS.md` から `@RTK.md` を参照します。
- hook はないので、shell command は `rtk` を前置する運用です。
- 例: `rtk git status`, `rtk cargo test`, `rtk npm run build`

### Gemini CLI

- `dot_gemini/settings.json` の `hooks.BeforeTool` が `~/.gemini/hooks/rtk-hook-gemini.sh` を呼びます。
- `run_shell_command` は hook 側で `rtk ...` へ書き換えられる前提です。
- 追加で圧縮出力を取りたいときは `rtk read`, `rtk grep`, `rtk find` を直接使ってください。

### GitHub Copilot

- `.github/hooks/rtk-rewrite.json` は `rtk hook copilot` を呼びます。
- VS Code Copilot Chat は `updatedInput` による transparent rewrite が使えます。
- Copilot CLI は upstream 制約で `updatedInput` を返せないため、hook は deny-with-suggestion を返します。提案された `rtk ...` command をそのまま実行してください。

## 生成・更新手順

通常の `rulesync generate` / `chezmoi re-add` は real home を触るので、この repo では fake HOME を使って差分を確認します。

```sh
tmp_home="$PWD/.tmp/rtk-home"
rm -rf "$tmp_home"
mkdir -p "$tmp_home/.config"
ln -s "$PWD/dot_config/rulesync" "$tmp_home/.config/rulesync"
ln -s "$PWD/dot_claude" "$tmp_home/.claude"
ln -s "$PWD/dot_codex" "$tmp_home/.codex"
ln -s "$PWD/dot_gemini" "$tmp_home/.gemini"
ln -s "$PWD/.github" "$tmp_home/.github"

(cd "$tmp_home/.config/rulesync" && HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" rulesync generate -t claudecode,codexcli,geminicli -f rules)
```

Copilot は current `rulesync` target が `~/.copilot/copilot-instructions.md` を生成するため、この repo では `dot_config/rulesync/.rulesync/rules/COPILOT.md` を source-of-truth にしつつ `.github/copilot-instructions.md` を repo 側で同期します。

RTK 公式の generator 自体を確認したいときは、repo 内 fake HOME に対して以下を実行します。

```sh
HOME="$tmp_home" ./path/to/rtk init -g --auto-patch
HOME="$tmp_home" ./path/to/rtk init -g --gemini
HOME="$tmp_home" ./path/to/rtk init -g --codex
(cd "$PWD" && HOME="$tmp_home" ./path/to/rtk init -g --copilot)
```

## 確認コマンド

```sh
MISE_TRUSTED_CONFIG_PATHS=$PWD mise ls-remote github:rtk-ai/rtk
taplo format --check dot_config/mise/config.toml
prettier --check dot_claude/settings.json dot_gemini/settings.json .github/copilot-instructions.md docs/rtk.md README.md
git diff -- dot_config/mise dot_config/rulesync dot_claude dot_codex dot_gemini .github docs README.md
```

## 既知の制約

- Claude Code の built-in tool (`Read` / `Grep` / `Glob`) は Bash hook を通りません。
- Codex は hook ではなく instruction ベースなので、`rtk` prefix を守る必要があります。
- Copilot CLI は `updatedInput` 非対応のため transparent rewrite ではありません。
- current `rulesync 7.23.0` の Copilot target は `.copilot/copilot-instructions.md` を生成するため、RTK 公式の `.github/copilot-instructions.md` とは path がずれています。
