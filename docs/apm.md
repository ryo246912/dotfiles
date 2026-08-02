# APM（Agent Package Manager）による外部スキル管理

[APM](https://github.com/microsoft/apm) は、AI エージェント用のスキル・プロンプト・MCP サーバ等の
プリミティブを `apm.yml` で宣言し、`apm install` で各エージェントの設定ディレクトリへ配布する
パッケージマネージャです。このリポジトリでは **外部スキルの管理** にのみ APM を利用します。

外部スキルは vendor（本文をリポジトリにコミット）せず、**すべて upstream リポジトリからの依存**として
`apm.yml`（`~/.apm/apm.yml`）に宣言します（npm の `package.json` に相当）。各依存は immutable なコミット
SHA に pin し、`apm install -g`（user scope）で各エージェントの skill ディレクトリ（`~/.claude/skills/`・
`~/.agents/skills/`）へ都度 install します。

## 役割分担（rulesync との住み分け）

| 対象                                | 管理ツール | ソース                                    | 配布先                                           |
| ----------------------------------- | ---------- | ----------------------------------------- | ------------------------------------------------ |
| このリポジトリの `CLAUDE.md`        | rulesync   | `.rulesync/rules/CLAUDE.md`               | リポジトリ直下の `CLAUDE.md`（gitignore）        |
| グローバルな自作 skill / rule / MCP | rulesync   | `dot_config/rulesync/exact_dot_rulesync/` | `~/.claude/` 等（chezmoi + `rulesync generate`） |
| **外部スキル（グローバル）**        | **APM**    | `dot_apm/apm.yml` の `dependencies.apm`   | `~/.claude/skills/` 等（`apm install -g`）       |

- **`CLAUDE.md` の生成方式は変更していません。** 従来どおり rulesync が生成します（`docs/rulesync.md` 参照）。
- **カスタムスキル**（`article` / `memo` / `planning` / `review-fix` / `suggest-rules` など、
  このリポジトリ独自の内容を含むもの）は引き続き rulesync（`dot_config/rulesync/`）で管理します。
- **外部スキル**（`crit` / `crit-cli` / `terminal-browser` / tsumiki 14種と commands）は upstream 依存として
  `dependencies.apm` に宣言します。skill 本文はこのリポジトリに持たず、pristine な upstream をそのまま使います。

## 依存の宣言と pin

`dot_apm/apm.yml` の `dependencies.apm` に `owner/repo/<skill への相対パス>#<コミット SHA>` 形式で
宣言します。パスは `SKILL.md` を含むディレクトリを指します。

```yaml
dependencies:
  apm:
    - tomasz-tomczyk/crit/integrations/claude-code/skills/crit#<sha>
    - git: zenbu-labs/terminal-browser
      path: skill
      ref: <sha>
      alias: terminal-browser
    - git: classmethod/tsumiki
      ref: <sha>
      alias: tsumiki
```

- **再現性**: 各依存を immutable なコミット SHA に pin することで、新しいマシンでも同じ内容が install
  されます（pin しないと HEAD 追従になり、upstream の変更が commit/レビュー無しに挙動を変えてしまう）。
- **SHA の取得・更新**: `git ls-remote https://github.com/<owner>/<repo> HEAD` で最新コミットを取得して差し替えます。
- subdirectory 依存の既定名は `<repo>-<directory>` になるため、terminal-browser は object form の
  `alias: terminal-browser` を指定して `skills/terminal-browser/` に配置します。
- tsumiki は個別 skill ではなく plugin package 全体を依存にすることで、14 skills に加えて commands も
  install します。`mise run apm:install` は Claude Code 用に commands を `~/.claude/commands/tsumiki/` にも
  コピーするため、`/tsumiki:init-tech-stack` のように namespace 付きで実行できます。
- `apm install -g` は解決結果を `~/.apm/apm.lock.yaml` にも記録します（integrity hash 付き）。より厳密な
  再現性が必要なら、生成された `~/.apm/apm.lock.yaml` を `chezmoi add` して commit してください
  （npm の `package-lock.json` に相当）。

## ディレクトリ構成

- `dot_apm/apm.yml` → `~/.apm/apm.yml`: user scope の APM マニフェスト（`targets` / `dependencies`）。
- `~/.apm/apm.lock.yaml` / `~/.apm/apm_modules/` / `~/.claude/skills/` 等: `apm install -g` の生成物（配布先）。

## 使い方

### 外部スキルを追加・更新する（依存として取り込む）

`dot_apm/apm.yml` の `dependencies.apm` を編集し（SHA pin 付き）、`chezmoi apply` → `mise run apm:install`
を実行します。

```bash
mise run apm:install
# または
apm install -g
```

`apm install -g` は cwd に依存せず `~/.apm/apm.yml` を読み、`targets` に応じた各エージェントの user scope
ディレクトリ（`claude` なら `~/.claude/skills/`、その他は `~/.agents/skills/`）へスキルを配置します。
`mise run apm:install` は install 後に tsumiki commands の Claude Code namespace も同期します。

> [!IMPORTANT]
> `~/.apm/` は chezmoi が生成するディレクトリなので、**先に `chezmoi apply` 済みであること**が前提です。
> 新しいマシンや `dot_apm/` を編集した直後は、`chezmoi apply` してから `mise run apm:install` を実行してください。

<!-- -->

> [!NOTE]
> 導入した skill の `description` は各エージェントの skill 索引に**常時ロード**されます。
> スキル数が多いほどコンテキスト（トークン）を消費するため、不要なものは
> `dependencies.apm` から外してください。tsumiki は現在14スキルを導入しています。

## 注意事項

- 配布先（`~/.claude/skills/` 等）は生成物です。skill 本文はこのリポジトリに持たないため、内容を変えたい
  場合は upstream を fork するか、`dependencies.apm` の pin を差し替えます。
- `apm` 本体はグローバルの mise（`dot_config/mise/config.toml`）の `github:microsoft/apm`
  バックエンド（GitHub リリースのバイナリ）で管理しています。
- `targets` は `claude` / `codex` / `copilot` / `cursor`。`claude` は `~/.claude/skills/`、
  それ以外は共通の `~/.agents/skills/` へ配布されます。
