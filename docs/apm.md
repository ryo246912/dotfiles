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
- **カスタムスキル**は引き続き rulesync（`dot_config/rulesync/`）で管理します。
- **外部スキル**は upstream 依存として `dependencies.apm` に宣言します。skill 本文はこのリポジトリに持たず、
  pristine な upstream をそのまま使います。

## 依存の宣言と pin

APMは依存先を取得した後、対象pathの構成からpackageを判別します。追加するときは、まずupstreamを確認して
次のどちらとして取り込むかを決めます。

- リポジトリ内の1つの`SKILL.md`だけが必要なら、**skill（virtual package）**としてそのdirectoryを`path`に指定する。
- リポジトリに`apm.yml`、またはClaude Code plugin形式のskills・commandsなどがあり、複数primitiveをまとめて
  取り込みたいなら、**plugin/package**としてリポジトリ全体を指定する。

### 1つのskillをインストールする

`path`には`SKILL.md`が置かれたdirectoryを指定します。短縮形でも書けますが、インストール名を明示する場合は
object formを使います。

```yaml
dependencies:
  apm:
    - git: owner/repository
      path: path/to/skill
      ref: <sha>
      alias: installed-skill-name
```

`alias`がローカルでのpackage名になり、skillの配置名を明示できます。`alias`を省略するとAPMがリポジトリ名と
subdirectory名から既定名を決めるため、期待するskill名と異なる場合だけ指定します。

### plugin/package全体をインストールする

複数のskillsやcommandsを含むplugin/packageは`path`を指定せず、リポジトリ全体を依存にします。

```yaml
dependencies:
  apm:
    - git: owner/plugin-repository
      ref: <sha>
      alias: plugin-name
```

pluginが選択可能なskillsを公開しており、その一部だけが必要な場合はobject formへ`skills`を追加します。

```yaml
dependencies:
  apm:
    - git: owner/plugin-repository
      ref: <sha>
      alias: plugin-name
      skills:
        - selected-skill
```

`skills`を省略するとpackage全体を取り込みます。`skills: ["*"]`は公開されたskillsをすべて選択します。
`alias`はpackageのローカル名であり、plugin内の個々のskill名を書き換える設定ではありません。

- **再現性**: 各依存を immutable なコミット SHA に pin することで、新しいマシンでも同じ内容が install
  されます（pin しないと HEAD 追従になり、upstream の変更が commit/レビュー無しに挙動を変えてしまう）。
- **SHA の取得・更新**: `git ls-remote https://github.com/<owner>/<repo> HEAD` で最新コミットを取得して差し替えます。
- 詳細なfieldと判別規則はAPM公式の[Manifest Schema](https://github.com/microsoft/apm/blob/main/docs/src/content/docs/reference/manifest-schema.md#41-dependenciesapm----listapmdependency)を参照してください。
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
`mise run apm:install` は続けて tsumiki commands を rulesync source へ同期し、Claude Codeにはcommand、
Codexにはskillとして配布します。Claude Codeでは `/tsumiki-init-tech-stack`、Codexでは新しいセッションから
`$tsumiki-init-tech-stack` のように呼び出します。Codexのcustom prompt（`/prompts:...`）には依存しません。
同期時は source directory 側の `dot_apm/apm.lock.yaml` を `0644` に正規化するため、APM が user scope の
lockfile を `0600` で生成しても、その後の `chezmoi apply` で mode 差分は表示されません。

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
