# rulesync

[rulesync](https://github.com/dyoshikawa/rulesync) は、ルール・スキル・フック・MCP設定を単一のソースから
Claude Code / Codex CLI / Copilot など複数の AI エージェント向け設定ファイルへ変換して配布する CLI ツールです。

このリポジトリには **2つの独立した rulesync 設定** があります。混同すると `generate` が失敗するので、
役割の違いを区別してください。

## 2つのスコープ

| スコープ         | 設定ファイル                          | ソース (`.rulesync` 相当)                       | 生成先                                                                | 用途                                                       |
| ---------------- | -------------------------------------- | ------------------------------------------------ | ---------------------------------------------------------------------- | ------------------------------------------------------------ |
| プロジェクト単位 | `rulesync.jsonc`（リポジトリ直下）      | `.rulesync/`（リポジトリ直下）                    | リポジトリ直下（`outputRoots: ["."]`）                                  | **このリポジトリ自身**の `CLAUDE.md` を生成する自己参照的な設定 |
| グローバル       | `dot_config/rulesync/rulesync.jsonc`   | `dot_config/rulesync/exact_dot_rulesync/`         | `~/.claude/`, `~/.codex/`, `~/.copilot/` など（`global: true` により実ホームへ書き込み） | どのプロジェクトでも使える skill / rule / hooks / MCP 設定の配布 |

- プロジェクト単位の設定が生成するのは、あなたが今読んでいる **この `CLAUDE.md` そのもの**です。
  ソースは `.rulesync/rules/CLAUDE.md` で、ここを編集して `rulesync generate` すると `CLAUDE.md` に反映されます。
  `CLAUDE.md` を直接編集しても次の `generate` で上書きされるので注意してください。
- グローバル設定は chezmoi で `~/.config/rulesync/` 配下に配布されます。
  - `dot_config/rulesync/rulesync.jsonc` → `~/.config/rulesync/rulesync.jsonc`
  - `dot_config/rulesync/exact_dot_rulesync/` → `~/.config/rulesync/.rulesync/`
    （`exact_` のため、chezmoi 管理外のファイルは `apply` 時に削除される）
  - `rulesync.jsonc` の `"global": true` により、`~/.config/rulesync` から実行しても出力は
    カレントディレクトリではなく実際の `$HOME` 配下（`~/.claude/skills/...` 等）に書き込まれる
  - ここに `/crit` などの skill（`dot_config/rulesync/exact_dot_rulesync/skills/`）や
    共通ルール（`dot_config/rulesync/exact_dot_rulesync/rules/COMMON.md`）、hooks
    （`dot_config/rulesync/exact_dot_rulesync/hooks.json`）が入っている

## 生成コマンド

```bash
mise run rulesync:generate
```

`dot_config/mise/tasks/dev.toml` で以下の2ステップを実行します。

```toml
run = [
    "cd \"$(chezmoi source-path)\" && rulesync generate",
    "cd ~/.config/rulesync && rulesync generate",
]
```

1. **プロジェクト単位**: `chezmoi source-path`（= このリポジトリのソースディレクトリ）へ `cd` してから実行。
   `mise run` をどのディレクトリから叩いても解決できるよう明示的に `cd` している。
2. **グローバル**: `~/.config/rulesync` へ `cd` してから実行。

> [!IMPORTANT]
> グローバル側は **`chezmoi apply` 済みであること**が前提です。`~/.config/rulesync/.rulesync/`
> は chezmoi が生成するディレクトリなので、`chezmoi apply` 前は存在せず
> `.rulesync directory not found. Run 'rulesync init' first.` で失敗します。
> 新しいマシンや `dot_config/rulesync/` を編集した直後は、先に `chezmoi apply` してから
> `mise run rulesync:generate` を実行してください。

## トラブルシューティング

### `.rulesync directory not found. Run 'rulesync init' first.`

`rulesync generate` は **カレントディレクトリ**の `rulesync.jsonc` / `.rulesync/` しか見ません。
以下のいずれかが原因です。

- `~/.config/rulesync/.rulesync/` が存在しない → `chezmoi apply` を実行する
- `mise run rulesync:generate` 以外の方法（直接 `rulesync generate` をどこかのディレクトリで実行）で
  呼び出した → プロジェクト単位なら `chezmoi cd`、グローバルなら `cd ~/.config/rulesync` してから実行する

### `'baseDirs' config field is deprecated; use 'outputRoots' instead.`

`rulesync.jsonc` に古い `baseDirs` フィールドが残っている場合に出る警告です。このリポジトリの
`rulesync.jsonc` / `dot_config/rulesync/rulesync.jsonc` は `outputRoots` へ移行済みなので、
この警告が出る場合はリポジトリが最新でない（`chezmoi apply` 前、または `git pull` 前）可能性が高いです。
