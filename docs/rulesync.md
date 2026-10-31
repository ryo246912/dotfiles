# rulesync

[rulesync](https://github.com/dyoshikawa/rulesync) は、ルール・スキル・フック・MCP設定を単一のソースから
Claude Code / Codex CLI / Copilot など複数の AI エージェント向け設定ファイルへ変換して配布する CLI ツールです。

このリポジトリには **2つの独立した rulesync 設定** があります。混同すると `generate` が失敗するので、
役割の違いを区別してください。

## 2つのスコープ

| スコープ         | 設定ファイル                       | ソース (`.rulesync` 相当)      | 生成先                                                                                                 | 用途                                                                                                                                                         |
| ---------------- | ---------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| プロジェクト単位 | `rulesync.jsonc`（リポジトリ直下） | `.rulesync/`（リポジトリ直下） | リポジトリ直下（`outputRoots: ["."]`）                                                                 | **このリポジトリ自身**の `CLAUDE.md` を生成する自己参照的な設定                                                                                              |
| グローバル       | `config/rulesync/rulesync.jsonc`   | `config/rulesync/.rulesync/`   | `~/.claude/`, `~/.codex/`, `~/.agents/`, `~/.copilot/` など（`global: true` により実ホームへ書き込み） | どのプロジェクトでも使える skill / rule / hooks の配布（MCP は agent に配布せず、sandbox 用に `config/sbx/mcp.yml` で管理。`docs/docker-sandboxes.md` 参照） |

- プロジェクト単位の設定が生成するのは、あなたが今読んでいる **この `CLAUDE.md` そのもの**です。
  ソースは `.rulesync/rules/CLAUDE.md` で、ここを編集して `rulesync generate` すると `CLAUDE.md` に反映されます。
  `CLAUDE.md` を直接編集しても次の `generate` で上書きされるので注意してください。
- グローバル設定は chezmoi で `~/.config/rulesync/` 配下に配布されます。
  - `config/rulesync/rulesync.jsonc` → `~/.config/rulesync/rulesync.jsonc`
  - `config/rulesync/.rulesync/` → `~/.config/rulesync/.rulesync/`
    （mise の `[dotfiles]` は copy モードのため、リポジトリ管理外のファイルが
    `~/.config/rulesync/.rulesync/` に残っていても削除はされない）
  - `rulesync.jsonc` の `"global": true` により、`~/.config/rulesync` から実行しても出力は
    カレントディレクトリではなく実際の `$HOME` 配下（`~/.claude/skills/...` 等）に書き込まれる
  - ここに自作 skill（`memo` / `planning` / `pr-reviewer-comment` 等、`config/rulesync/.rulesync/skills/`）や
    共通ルール（`config/rulesync/.rulesync/rules/COMMON.md`）、hooks
    （`config/rulesync/.rulesync/hooks.json`）、permissions
    （`config/rulesync/.rulesync/permissions.jsonc`）が入っている

> [!NOTE]
> サードパーティ由来の**外部スキル**（独自カスタマイズを含まないもの）は rulesync ではなく
> APM で管理します。vendor せず `apm/apm.yml` の `dependencies.apm` に upstream 依存として
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

| 種類                               | 例                                                                              | git 管理 | 理由                                                                                                                              |
| ---------------------------------- | ------------------------------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------- |
| プロジェクト単位の rulesync 設定   | `rulesync.jsonc`                                                                | する     | generate の入力であり、リポジトリ固有の target / output 設定だから                                                                |
| プロジェクト単位の rulesync source | `.rulesync/rules/CLAUDE.md`, `.rulesync/hooks.json`                             | する     | 生成物の正本だから                                                                                                                |
| プロジェクト単位の生成物           | `CLAUDE.md`                                                                     | しない   | `rulesync generate` で再生成される出力だから                                                                                      |
| プロジェクト単位の hooks 生成物    | `.claude/settings.json`, `.codex/hooks.json`                                    | する     | 新しい clone やクラウド環境では rulesync を実行する前に AI のセッションが始まり、生成物がないと SessionStart フックが動かないから |
| グローバル配布用の rulesync 設定   | `config/rulesync/rulesync.jsonc`                                                | する     | `[dotfiles]` で `~/.config/rulesync/rulesync.jsonc` へ配布する入力だから                                                          |
| グローバル配布用の rulesync source | `config/rulesync/.rulesync/rules/COMMON.md`, `.../skills/*/SKILL.md`            | する     | `[dotfiles]` で `~/.config/rulesync/.rulesync/` へ配布する正本だから                                                              |
| グローバル生成物                   | `~/.claude/`, `~/.codex/`, `~/.agents/`, `~/.copilot/` 配下へ生成されるファイル | しない   | `rulesync generate` で実ホームへ再生成される出力だから                                                                            |

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

グローバル側も同様に、source の正本は `config/rulesync/.rulesync/` 配下で git 管理し、
chezmoi が `~/.config/rulesync/.rulesync/` へ展開します。実ホーム側の `~/.config/rulesync/.rulesync/` で
直接 `rulesync init` して作ったファイルは、正本ではないため git 管理しません。必要な内容だけ
`config/rulesync/.rulesync/` へ移してください。

## hooks と permissions（グローバル）

`~/.claude` と `~/.codex` は repo の `claude/`・`codex/` への symlink-each（`mise.toml` 参照）なので、
グローバル generate が書き込む `~/.claude/settings.json`・`~/.codex/hooks.json`・`~/.codex/config.toml` は
そのまま repo の `claude/settings.json`・`codex/hooks.json`・`codex/config.toml` になる。これらの
`hooks` / `permissions` 部分は rulesync の出力なので、直接編集せず source 側を編集して generate すること
（それ以外のキー、例えば `claude/settings.json` の `env` や `statusLine` は手で編集してよい）。

### hooks（`config/rulesync/.rulesync/hooks.json`）

CodeRabbit CLI のローカルレビューは Claude Code・Codex CLI・Copilot CLI の
`preToolUse` に登録しています。共通の実体は
`config/devcontainer/scripts/coderabbit-review.sh`（配置先は
`~/.config/devcontainer/scripts/coderabbit-review.sh`）です。
Claude / Codex の `tool_input` と Copilot の `toolArgs`（オブジェクトまたは JSON 文字列）から
コマンドを読み、`git push`・`gh pr create`（単独、または `&&` の後）だけを対象にします。
`.coderabbit.yaml` と CLI がある場合に HEAD ごとに一度レビューし、結果を agent に返して
その実行を止めます。CLI の失敗時は続行します。
Copilot CLI は rulesync 32.0.0 の matcher 制限を避けてスクリプト側で判定します。
変更後は `mise run rulesync:generate` を実行し、各 CLI を再起動してください。

| ブロック           | 生成先                                | 内容                                                               |
| ------------------ | ------------------------------------- | ------------------------------------------------------------------ |
| `claudecode.hooks` | `~/.claude/settings.json`             | ai-rule-hook、plannotator、rtk、編集後の formatter / type check 等 |
| `codexcli.hooks`   | `~/.codex/hooks.json`                 | ai-rule-hook（`UserPromptSubmit` / `Stop`）、plannotator           |
| `copilot.hooks`    | `~/.copilot/hooks/copilot-hooks.json` | ai-rule-hook（`copilotcli` target が `copilot.hooks` を参照する）  |

`rulesync.jsonc` の `"preserveUnownedHooks": true` により、rulesync が書いていない hooks（APM が
plugin package から merge する ponytail の hooks 等）は generate 後も残る。rulesync が書いた hooks は
各 hooks ファイルの隣の `.rulesync-hooks-lock.json` に記録され、source から消した hooks だけが削除される。
この設定が無いと rulesync は hooks 一覧を丸ごと置き換えるため、generate のたびに APM 由来の hooks が消える。

### permissions（`config/rulesync/.rulesync/permissions.jsonc`）

共通の `permission` ブロックで `sudo` / `rm -rf` と秘匿ファイル（`.env`・`.envrc`・`*.secret`・
`fnox.local.toml`・SSH 鍵・`secrets/`）へのアクセスを禁止し、ツールごとの差分を tool-scoped ブロックで上書きする
（tool-scoped の category は共通側の同名 category を丸ごと置き換えるので、共通のルールも再掲している）。

- Claude Code: `~/.claude/settings.json` の `permissions.deny` に生成する。ファイル名に `token` / `key` を含む
  ファイルも広く Read 禁止にしている（Claude Code の Read deny は Read ツールだけに効くため影響が小さい）。
- Codex CLI: bash ルールは `~/.codex/rules/rulesync.rules`（execpolicy の `forbidden`）、ファイルのルールは
  `~/.codex/config.toml` の `[permissions.rulesync]` プロファイルに生成する。Codex のファイル deny は
  サンドボックス内のシェルコマンドにも効くため、`*token*` / `*key*` のような広い glob は入れていない。
  rulesync が生成するプロファイルは `:workspace` を継承し、従来の `workspace-write` よりも厳しい
  （ワークスペース外の読み取りや一時ディレクトリへの書き込みが拒否される）ため、`:root` の読み取りと
  `:tmpdir` / `:slash_tmp` への書き込みを許可して従来相当にしている。承認は従来どおりユーザーが行う
  （`approvals_reviewer = "user"`。rulesync の既定は `auto_review`）。
- `~/.codex/config.toml` のその他のキー（`shell_environment_policy` 等）は rulesync が保持するが、
  コメントは保持されない。

## skill のコンテキストへの載せ方

自作 skill（`config/rulesync/.rulesync/skills/`）を足したら、`claude/settings.json` の `skillOverrides` にも追加します
（[`docs/ai.md` の「skill のコンテキスト管理」](ai.md#skill-のコンテキスト管理)）。

## 生成コマンド

```bash
mise --cd "$HOME" run rulesync:generate
```

`config/mise/tasks/dev.toml` で以下の2ステップを実行します。

1. **プロジェクト単位**: dotfiles リポジトリの checkout を `DOTFILES_DIR`（既定 `~/dotfiles`。
   別の場所に clone している場合は export で上書きする）として解決する。task 側は
   `$DOTFILES_DIR/mise.toml` の有無で本物の checkout か検証したうえで、`rulesync.jsonc` と
   `.rulesync/` が両方ある場合だけ `cd` して実行する。
2. **グローバル**: `~/.config/rulesync` に `rulesync.jsonc` と `.rulesync/` が両方ある場合だけ `cd` して実行する。

どちらかのスコープが未初期化でも、もう片方の生成を止めないように warning を出して skip します。

`mise run rulesync:sync`（bootstrap の post-dotfiles hook から呼ばれる）は source のハッシュに加えて
`rulesync --version` も比較するため、rulesync を upgrade しただけでも次回の sync で再生成されます。

## トラブルシューティング

### `.rulesync directory not found. Run 'rulesync init' first.`

`rulesync generate` は **カレントディレクトリ**の `rulesync.jsonc` / `.rulesync/` しか見ません。
以下のいずれかが原因です。

- `~/.config/rulesync/.rulesync/` が存在しない → `mise bootstrap dotfiles apply` を実行する
- `mise run rulesync:generate` 以外の方法（直接 `rulesync generate` をどこかのディレクトリで実行）で
  呼び出した → プロジェクト単位なら `cd ~/dotfiles`（`DOTFILES_DIR`）、グローバルなら
  `cd ~/.config/rulesync` してから実行する

### `'baseDirs' config field is deprecated; use 'outputRoots' instead.`

`rulesync.jsonc` に古い `baseDirs` フィールドが残っている場合に出る警告です。このリポジトリの
`rulesync.jsonc` / `config/rulesync/rulesync.jsonc` は `outputRoots` へ移行済みなので、
この警告が出る場合はリポジトリが最新でない（`mise bootstrap dotfiles apply` 前、または `git pull` 前）可能性が高いです。

### `~/.codex/skills/` に古い skill が残っている

rulesync v9.1.0 以降、Codex CLI 向け skill の出力先は `~/.codex/skills/` から Codex 標準の
`~/.agents/skills/`（APM と同じ場所）へ移動しました。`delete: false` のため旧出力は自動では削除されず、
Codex で同じ skill が重複して見える場合があります。tsumiki 由来の skill（`tsumiki-*`）は
`mise run apm:install` が state manifest を元に削除しますが、自作 skill（`memo` / `planning` 等）の旧出力は
手動で削除してください。

```bash
ls ~/.codex/skills/   # ~/.agents/skills/ に同名の skill があることを確認してから削除する
```

### 自作 skill を消しても配布先に残る

`config/rulesync/.rulesync/skills/` から skill を消しても、`delete: false` のため `~/.claude/skills/` と
`~/.agents/skills/` の生成物は残ります。手動で削除してください。

```bash
rm -rf ~/.claude/skills/<name> ~/.agents/skills/<name>
```

`delete: true` にはしません。`--delete` は出力先のうち `.rulesync/` から生成されなかったファイルを消すため、
同じ `~/.claude/skills/`・`~/.agents/skills/` に APM が置いた外部 skill まで消えてしまいます。

### プロジェクト単位の `.codex/config.toml` について

以前は Codex CLI の hooks を有効化するため `.codex/config.toml` に `[features] hooks = true` が生成されていましたが、
Codex CLI の hooks が GA（デフォルト有効）になったため、rulesync は生成しなくなりました。
このリポジトリでも git 管理から外しています。
