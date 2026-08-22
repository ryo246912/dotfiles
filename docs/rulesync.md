# rulesync

[rulesync](https://github.com/dyoshikawa/rulesync) は、ルール・スキル・フック・MCP設定を単一のソースから
Claude Code / Codex CLI / Copilot など複数の AI エージェント向け設定ファイルへ変換して配布する CLI ツールです。

このリポジトリには **2つの独立した rulesync 設定** があります。混同すると `generate` が失敗するので、
役割の違いを区別してください。

## 2つのスコープ

| スコープ         | 設定ファイル                         | ソース (`.rulesync` 相当)                 | 生成先                                                                                   | 用途                                                             |
| ---------------- | ------------------------------------ | ----------------------------------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| プロジェクト単位 | `rulesync.jsonc`（リポジトリ直下）   | `.rulesync/`（リポジトリ直下）            | リポジトリ直下（`outputRoots: ["."]`）                                                   | **このリポジトリ自身**の `CLAUDE.md` を生成する自己参照的な設定  |
| グローバル       | `dot_config/rulesync/rulesync.jsonc` | `dot_config/rulesync/exact_dot_rulesync/` | `~/.claude/`, `~/.codex/`, `~/.copilot/` など（`global: true` により実ホームへ書き込み） | どのプロジェクトでも使える skill / rule / hooks / MCP 設定の配布 |

- プロジェクト単位の設定が生成するのは、あなたが今読んでいる **この `CLAUDE.md` そのもの**です。
  ソースは `.rulesync/rules/CLAUDE.md` で、ここを編集して `rulesync generate` すると `CLAUDE.md` に反映されます。
  `CLAUDE.md` を直接編集しても次の `generate` で上書きされるので注意してください。
- グローバル設定は chezmoi で `~/.config/rulesync/` 配下に配布されます。
  - `dot_config/rulesync/rulesync.jsonc` → `~/.config/rulesync/rulesync.jsonc`
  - `dot_config/rulesync/exact_dot_rulesync/` → `~/.config/rulesync/.rulesync/`
    （`exact_` のため、chezmoi 管理外のファイルは `apply` 時に削除される）
  - `rulesync.jsonc` の `"global": true` により、`~/.config/rulesync` から実行しても出力は
    カレントディレクトリではなく実際の `$HOME` 配下（`~/.claude/skills/...` 等）に書き込まれる
  - ここに自作 skill（`article` / `memo` / `planning` 等、`dot_config/rulesync/exact_dot_rulesync/skills/`）や
    共通ルール（`dot_config/rulesync/exact_dot_rulesync/rules/COMMON.md`）、hooks
    （`dot_config/rulesync/exact_dot_rulesync/hooks.json`）が入っている

> [!NOTE]
> サードパーティ由来の**外部スキル**（独自カスタマイズを含まないもの）は rulesync ではなく
> APM で管理します。vendor せず `dot_apm/apm.yml` の `dependencies.apm` に upstream 依存として
> （コミット SHA pin 付きで）宣言し、`apm install -g` で `~/.claude/skills/` 等へ配布します。
> 詳細は `docs/apm.md` を参照。

tsumiki は例外的に、APM が取得した plugin package の `commands/` を
`mise run apm:sync-commands` で `~/.config/rulesync/.rulesync/commands/` へ同期します。APM は
command namespace と Codex commands に対応しないためです。Claude Code向けには各ファイルを
`tsumiki-<name>.md`へ変換し、`/tsumiki-<name>`として利用できるようにします。Codex向けには同じ内容を
Agent Skillへ変換するため、`$tsumiki-<name>`として利用できます。deprecatedなCodex custom promptの
`/prompts:...`形式には依存しません。同期対象はmise task内のPython `command_sources`で宣言し、他の外部packageも
module path・namespace・APMが生成したnamespaceなしcommandの削除先を追加して配布できます。sourceの同期と生成は
`mise run apm:install` がまとめて実行します。

## `rulesync init` で生成されるファイルの扱い

このリポジトリでは **rulesync のソースは git 管理し、rulesync の出力先は原則 git 管理しません**。
ただし、プロジェクト単位スコープの出力である `CLAUDE.md` は「このリポジトリ自体で参照したい生成物」なので、
例外的にリポジトリ直下へ生成しますが、`.gitignore` で git 管理から外しています。

| 種類                               | 例                                                                                | git 管理 | 理由                                                                |
| ---------------------------------- | --------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------- |
| プロジェクト単位の rulesync 設定   | `rulesync.jsonc`                                                                  | する     | generate の入力であり、リポジトリ固有の target / output 設定だから  |
| プロジェクト単位の rulesync source | `.rulesync/rules/CLAUDE.md`                                                       | する     | `CLAUDE.md` を生成するための正本だから                              |
| プロジェクト単位の生成物           | `CLAUDE.md`                                                                       | しない   | `rulesync generate` で再生成される出力だから                        |
| グローバル配布用の rulesync 設定   | `dot_config/rulesync/rulesync.jsonc`                                              | する     | chezmoi で `~/.config/rulesync/rulesync.jsonc` へ配布する入力だから |
| グローバル配布用の rulesync source | `dot_config/rulesync/exact_dot_rulesync/rules/COMMON.md`, `.../skills/*/SKILL.md` | する     | chezmoi で `~/.config/rulesync/.rulesync/` へ配布する正本だから     |
| グローバル生成物                   | `~/.claude/`, `~/.codex/`, `~/.copilot/` 配下へ生成されるファイル                 | しない   | `rulesync generate` で実ホームへ再生成される出力だから              |

### 初回 clone と `rulesync init` の関係

Rulesync では、`rulesync init` が作る `rulesync.jsonc` と `.rulesync/` が **初期化済みかどうかの実体**です。
追加のローカル DB や hidden state を作って「初期化済み」と記録する仕組みではありません。そのため、初回
`git clone` 直後でも、git 管理された `rulesync.jsonc` と `.rulesync/rules/CLAUDE.md` が存在していれば、
その clone は rulesync 的にはすでに初期化済みです。

この状態で `mise run rulesync:generate` を実行しても、`.rulesync/rules/CLAUDE.md` は **入力 source**、
リポジトリ直下の `CLAUDE.md` は **生成 output** なので、パスが異なりバッティングしません。output の
`CLAUDE.md` は `.gitignore` で git 管理から外しているため、初回生成で作られるローカル生成物として扱います。

### 既存ファイルと `rulesync init` のバッティングについて

`rulesync init` は、新規プロジェクトに `rulesync.jsonc` と `.rulesync/` の雛形を作るためのコマンドです。
このリポジトリにはすでに `rulesync.jsonc` と `.rulesync/rules/CLAUDE.md` があるため、
**リポジトリ直下で `rulesync init` を再実行する必要はありません**。既存の `.rulesync/rules/CLAUDE.md` と
init が作ろうとする雛形がぶつかる場合は、init ではなく既存の source を編集してください。

もし別リポジトリで、すでに手書きの `CLAUDE.md` や他ツール用 rule ファイルがある状態から rulesync へ移行するなら、
`rulesync init` で上書き方向に進めるのではなく、既存 output を `.rulesync/` 側へ取り込む `rulesync import` 系の
ワークフローを使うか、手で `.rulesync/rules/` に移してから生成 output を `.gitignore` に入れてください。

グローバル側も同様に、source の正本は `dot_config/rulesync/exact_dot_rulesync/` 配下で git 管理し、
chezmoi が `~/.config/rulesync/.rulesync/` へ展開します。実ホーム側の `~/.config/rulesync/.rulesync/` で
直接 `rulesync init` して作ったファイルは、正本ではないため git 管理しません。必要な内容だけ
`dot_config/rulesync/exact_dot_rulesync/` へ移してください。

## 生成コマンド

```bash
mise run rulesync:generate
```

`dot_config/mise/tasks/dev.toml` で以下の2ステップを実行します。

1. **プロジェクト単位**: `chezmoi apply` の post hook からは、テンプレート変数 `.chezmoi.sourceDir` で
   解決した実行中の chezmoi source directory を `CHEZMOI_SOURCE_DIR` として `mise run rulesync:generate` へ渡す。
   そのため、`sourceDir = ...` や `chezmoi apply --source ...` で非既定の source directory を使う場合も同じ
   source directory を参照できる。task 側は `CHEZMOI_SOURCE_DIR` 配下に `rulesync.jsonc` と `.rulesync/` が
   両方ある場合だけ `cd` して実行する。
   `chezmoi apply` の post hook 中は chezmoi が persistent state lock を保持しうるため、ここでは
   `chezmoi source-path` を呼ばない。
2. **グローバル**: `~/.config/rulesync` に `rulesync.jsonc` と `.rulesync/` が両方ある場合だけ `cd` して実行する。

どちらかのスコープが未初期化でも、もう片方の生成を止めないように warning を出して skip します。

## 会話のフィードバックからルール候補を作る hook

[Claude Code の Hooks でフィードバックを残す仕組み](https://zenn.dev/nozomi720/articles/claude_code_hooks_feedback)
を参考に、会話履歴から再利用可能なルール追記候補・スキル化候補を作る hook をグローバル設定に含めています。
既存ルールを直接増やし続ける方式ではなく、候補を一度確認してから rulesync の正本へ反映する方式です。

### 配布と devcontainer 内での実行

1. `dot_config/rulesync/exact_dot_rulesync/hooks.json` を rulesync の hook source とする。
2. `chezmoi apply` と `mise run rulesync:generate` により Claude Code の user scope へ hook を生成する。
3. devcontainer はホストの `~/.claude` と `~/.config/devcontainer/scripts` を bind mount するため、コンテナ内で
   起動した Claude Code も同じ hook 設定と runner を使用する。
4. `SessionEnd` / `PreCompact` で runner が transcript の末尾を読み、別の非対話 Claude プロセスで候補を生成する。
   再帰実行は `AI_RULE_HOOK_RUNNING` で防止する。

候補は自動でルールへ追記しません。セッション別の結果は
`${XDG_STATE_HOME:-$HOME/.local/state}/ai-rule-hook/claude/<session>/`、最新の結果は
`${XDG_STATE_HOME:-$HOME/.local/state}/ai-rule-hook/claude/latest.md` で確認できます。採用する場合は、グローバル
ルールなら `dot_config/rulesync/exact_dot_rulesync/rules/COMMON.md`、定型作業なら同ディレクトリ配下の
`skills/<name>/SKILL.md` に反映し、再度 `chezmoi apply` と `mise run rulesync:generate` を実行してください。

hook runner は transcript とルールの読み込み量に上限を設け、秘密情報・個人情報・一時的な事情を候補から除外する
prompt を使用します。それでも transcript を外部の AI CLI へ渡す処理であるため、無効化したい場合は
rulesync source の `sessionEnd` / `preCompact` を削除して再生成してください。

### 動作確認

AI を呼び出さず payload の解釈と生成対象を確認できます。

```bash
transcript=$(mktemp)
printf '%s\n' '{"type":"user","message":{"role":"user","content":"test"}}' >"$transcript"
jq -nc --arg transcript "$transcript" \
  '{hook_event_name:"SessionEnd",session_id:"smoke-test",transcript_path:$transcript}' \
  | AI_RULE_HOOK_DRY_RUN=1 ~/.config/devcontainer/scripts/ai-rule-hook.sh --tool claude
rm -f "$transcript"
```

`should_run` が `true` になり、`canonical_event` が `session_end` なら hook payload は認識されています。

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
