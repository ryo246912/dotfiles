# APM（Agent Package Manager）による外部スキル管理

[APM](https://github.com/microsoft/apm) は、AI エージェント用のスキル・プロンプト・MCP サーバ等の
プリミティブを `apm.yml` で宣言し、`apm install` で各エージェントの設定ディレクトリへ配布する
パッケージマネージャです。このリポジトリでは **外部スキルの管理** に APM を利用します。

外部スキルは vendor（本文をリポジトリにコミット）せず、**すべて upstream リポジトリからの依存**として
`apm.yml`（`~/.apm/apm.yml`）に宣言します（npm の `package.json` に相当）。各依存は release tag、または
`apm.lock.yaml` の commit で pin し、`apm install -g`（user scope）で各エージェントの skill ディレクトリ
（`~/.claude/skills/`・`~/.agents/skills/`）へ都度 install します。依存と lockfile の更新は Renovate の
[apm manager](https://docs.renovatebot.com/modules/manager/apm/) が行います（後述）。

## 役割分担（rulesync との住み分け）

| 対象                          | 管理ツール | ソース                                                       | 配布先                                                                 |
| ----------------------------- | ---------- | ------------------------------------------------------------ | ---------------------------------------------------------------------- |
| このリポジトリの `CLAUDE.md`  | rulesync   | `.rulesync/rules/CLAUDE.md`                                  | リポジトリ直下の `CLAUDE.md`（gitignore）                              |
| グローバルな自作 skill / rule | rulesync   | `config/rulesync/.rulesync/`                                 | `~/.claude/` 等（mise `[dotfiles]` + `rulesync generate`）             |
| **外部スキル（グローバル）**  | **APM**    | `apm/apm.yml` の `dependencies.apm`                          | `~/.claude/skills/` 等（`apm install -g`）                             |
| MCP サーバ（sandbox 用）      | sbx mcp    | `config/sbx/mcp.yml`（APM の `dependencies.mcp` と同じ書式） | ホストの `sbx mcp`（`mise run sandbox:mcp-add`）。agent には登録しない |

- **`CLAUDE.md` の生成方式は変更していません。** 従来どおり rulesync が生成します（`docs/rulesync.md` 参照）。
- **カスタムスキル**は引き続き rulesync（`config/rulesync/`）で管理します。
- **外部スキル**は upstream 依存として `dependencies.apm` に宣言します。skill 本文はこのリポジトリに持たず、
  pristine な upstream をそのまま使います。

## MCP サーバ

MCP サーバは **ホストの agent には登録せず**、Docker Sandboxes からホストの `sbx mcp`（gateway）経由でだけ
使います。そのため `apm install -g` は `--only apm` で実行し（`apm:install` / `apm:ci`）、MCP は
`~/.claude.json` などへ書き込みません。`apm.yml` の `dependencies.mcp` は空のままにします。

- `dependencies.mcp` に書くと、`--only apm` では lockfile に載らないため `apm install --frozen`（`apm:ci`）が
  「MCP server '...' is missing from apm.lock.yaml」で失敗します。
- MCP の定義とバージョンは `config/sbx/mcp.yml` に、APM の `dependencies.mcp` と同じ書式で書きます
  （詳細は `docs/docker-sandboxes.md` の「MCP の扱い」）。
- rulesync から移行したホストでは、以前 rulesync が配布した定義が残ります。一度だけ
  `~/.config/rulesync/.rulesync/mcp.json` を削除し、`~/.copilot/mcp-config.json` から旧名
  （`makenotion/notion-mcp-server`・`io.github.ChromeDevTools/chrome-devtools-mcp` など）の
  エントリを消してください（rulesync の `mcp` target は外してあるので再生成はされません）。

## 依存の宣言と pin

APMは依存先を取得した後、対象pathの構成からpackageを判別します。追加するときは、まずupstreamを確認して
次のどちらとして取り込むかを決めます。

- リポジトリ内の1つの`SKILL.md`だけが必要なら、**skill（virtual package）**としてそのdirectoryを`path`に指定する。
- リポジトリに`apm.yml`、またはClaude Code plugin形式のskills・commandsなどがあり、複数primitiveをまとめて
  取り込みたいなら、**plugin/package**としてリポジトリ全体を指定する。

### 書式（文字列形式で書く）

Renovate の apm manager は `dependencies.apm` の**文字列形式**（`owner/repo[/path]#<ref>`）だけを読みます。
object 形式（`git:`/`path:`/`ref:`/`alias:`）の依存は Renovate に無視されるため、更新を Renovate に任せる
依存は文字列形式で書きます。

```yaml
dependencies:
  apm:
    # 1つのskill（virtual package）: SKILL.md が置かれた directory を path に書く
    - owner/repository/path/to/skill#v1.2.3
    # plugin/package全体: path を書かない
    - owner/plugin-repository#v2.0.0
    # release tag の無い依存: ref を書かず、apm.lock.yaml の commit で pin する
    - owner/no-tag-repository/path/to/skill
```

配置名は path の末尾（path が無ければ repo 名）になります。これが期待する skill 名と異なる場合だけ、object
形式の `alias` で配置名を明示します（例: `zenbu-labs/terminal-browser` の `skill/`）。object 形式の依存は
Renovate で更新されないため、upstream の変更で使えなくなったなどの理由で意図的に固定する依存に限ります。

pluginが選択可能なskillsを公開しており、その一部だけが必要な場合はobject formへ`skills`を追加します
（この場合も Renovate では更新されません）。

```yaml
dependencies:
  apm:
    - git: owner/plugin-repository
      ref: v2.0.0
      skills:
        - selected-skill
```

`skills`を省略するとpackage全体を取り込みます。`skills: ["*"]`は公開されたskillsをすべて選択します。

### pin と Renovate による更新

- **release tag がある依存**は `#<tag>` に pin します。Renovate（`github-tags` datasource）が新しい tag を
  見つけると `apm.yml` を更新し、同じPRで `apm install` を実行して `apm.lock.yaml` も更新します。
  CLI も配布するリポジトリ（plannotator・crit・ctx・desloppify など）は `.github/renovate.json` の `groupName` で mise の
  CLI 更新と同一PRにまとめます。
- **release tag が無い依存**（effective-html・tsumiki・diagram-design）は ref を書きません。`apm.lock.yaml`
  の `resolved_commit` が pin になり、manifest の他の依存が変わっても lockfile の commit が維持されます。
  Renovate の lockFileMaintenance（`.github/renovate.json` の `apm.lockFileMaintenance`、既定の schedule は
  週1回）が lockfile を作り直し、最新 commit へ更新するPRを作ります。
- **Renovate で更新しない依存**: `resolving-merge-conflicts`（v1.3.0 で upstream から削除）は
  `.github/renovate.json` の packageRules で無効化し、`terminal-browser` は object 形式なので対象外です。desloppify も object 形式ですが、
  `.github/renovate.json` の regex manager が `ref` だけを更新し、mise の `pipx:desloppify` と同じPRにまとめます。
  組み込みの apm manager ではないため lockfile は再生成されず、そのPRのブランチで
  `mise run apm:lock-local` を実行して lockfile を再生成し、commit します。
- 詳細なfieldと判別規則はAPM公式の[Manifest Schema](https://github.com/microsoft/apm/blob/main/docs/src/content/docs/reference/manifest-schema.md#41-dependenciesapm----listapmdependency)を参照してください。

### Renovate が lockfile を生成する仕組みと制約

Renovate は `apm/` で project scope の `apm install`（`-g` なし）を実行して `apm.lock.yaml` を再生成します。
このリポジトリで使う lockfile は user scope（`apm install -g`）のものなので、両者が同じ内容になるように
次の構成にしています。

- **`targets` に `copilot` を含めない**: copilot は scope によって配布先が異なり（project scope は `.github/`、
  user scope は `~/.copilot/`）、tsumiki の commands や ponytail の hooks の配布先が lockfile に入るため、
  scope ごとに lockfile が変わってしまいます。`claude`・`codex`・`cursor` は両 scope で同じ内容になります。
- **APM CLI の version を揃える**: lockfile の `apm_version` が mise の APM と一致しないと
  `mise run apm:validate-lock-version` が失敗します。そのため mise の `github:microsoft/apm`、
  `.github/renovate.json` の `constraints.apm`（Renovate が `apm install` に使う version）、
  `apm/apm.lock.yaml` の `apm_version` をすべて `microsoft/apm` として抽出し（`constraints.apm` は組み込みの
  renovate-config manager、`apm_version` は regex manager）、`apm` group の同じPRで揃えて更新します。Renovate は `constraints` を base branch の設定から読むため、このPRで新しい
  APM による lockfile の再生成はできず、`apm_version` の値だけを書き換えます（0.32.0 → 0.33.0 では、
  書き換えた lockfile で `apm install -g --frozen` が成功し、lockfile の内容も変わらないことを確認済み）。
  新しい APM で content hash の計算方法などが変わり install が失敗する場合は、ローカルで
  `mise run apm:lock-local --update` を実行して `apm/apm.lock.yaml` を再生成してから commit してください。
  このタスクは一時ディレクトリで project scope の `apm install` を実行するだけで、`~/.apm` には触れないため、
  feature ブランチの worktree でも現在の checkout の `apm/apm.yml` から lockfile を作れます。
- **project scope の生成物を commit しない**: `apm install` は `apm/` 配下に `.claude/`・`.agents/`・
  `apm_modules/` などを生成します。Renovate は変更・未追跡ファイルをすべてPRに含めるため、`.gitignore` で
  `apm/apm.yml`・`apm/apm.lock.yaml` 以外を除外しています。

## ディレクトリ構成

- `apm/apm.yml` → `~/.apm/apm.yml`: user scope の APM マニフェスト（`targets` / `dependencies`）。
- `~/.apm/apm.lock.yaml` / `~/.apm/apm_modules/` / `~/.claude/skills/` 等: `apm install -g` の生成物（配布先）。

## 使い方

### 外部スキルを追加・更新する（依存として取り込む）

`apm/apm.yml` の `dependencies.apm` を編集し（tag pin、tag が無ければ ref なし）、`mise bootstrap dotfiles apply` → `mise --cd "$HOME" run apm:install`
を実行します。

```bash
mise --cd "$HOME" run apm:install
# または
apm install -g
```

`apm install -g` は cwd に依存せず `~/.apm/apm.yml` を読み、`targets` に応じた各エージェントの user scope
ディレクトリ（`claude` なら `~/.claude/skills/`、その他は `~/.agents/skills/`）へスキルを配置します。
`mise run apm:install` は続けて tsumiki commands を rulesync source へ同期し、Claude Codeにはcommand、
Codexにはskillとして配布します。Claude Codeでは `/tsumiki-init-tech-stack`、Codexでは新しいセッションから
`$tsumiki-init-tech-stack` のように呼び出します。Codexのcustom prompt（`/prompts:...`）には依存しません。
`mise bootstrap` の `[bootstrap.hooks.final]` は `~/.apm/apm.yml` と `~/.apm/apm.lock.yaml` の内容を
前回の成功時と比較し、変更がない場合はこの install・command 同期・command生成をスキップします。
手動の `mise --cd "$HOME" run apm:install` はこの判定に関係なく常に実行できます。
同期時は source directory 側の `apm/apm.lock.yaml` を `0644` に正規化するため、APM が user scope の
lockfile を `0600` で生成しても、その後の `mise bootstrap dotfiles apply` で mode 差分は表示されません。

> [!NOTE]
> 導入した skill の `description` は各エージェントの skill 索引に**常時ロード**されます。
> スキル数が多いほどコンテキスト（トークン）を消費するため、不要なものは
> `dependencies.apm` から外してください。tsumiki は現在14スキルを導入しています。

## コンテキストへの載せ方

外部スキルを足したら、`claude/settings.json` の `skillOverrides` にも追加して一覧への載せ方を決めます
（書かないと `"on"` 扱いになり、説明文も一覧に載る）。詳細は [`docs/ai.md` の「skill のコンテキスト管理」](ai.md#skill-のコンテキスト管理) を参照してください。

## 注意事項

- 配布先（`~/.claude/skills/` 等）は生成物です。skill 本文はこのリポジトリに持たないため、内容を変えたい
  場合は upstream を fork するか、`dependencies.apm` の pin を差し替えます。
- `apm` 本体はグローバルの mise（`config/mise/config.toml`）の `github:microsoft/apm`
  バックエンド（GitHub リリースのバイナリ）で管理しています。
- `targets` は `claude` / `codex` / `cursor`。`claude` は `~/.claude/skills/`、
  それ以外は共通の `~/.agents/skills/` へ配布されます。`copilot` を外している理由は
  「Renovate が lockfile を生成する仕組みと制約」を参照してください。
