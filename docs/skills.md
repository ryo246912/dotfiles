# skill のコンテキスト管理

skill の本体は APM（[`docs/apm.md`](apm.md)）と rulesync（[`docs/rulesync.md`](rulesync.md)）で global
（`~/.claude/skills` など）に配布したまま、**Claude に見せるかどうか**だけを設定で切り替えます。

## skill はどれだけコンテキストを使うか

- 常に入るのは、各 skill の**名前と説明文の一覧**だけです（Claude がどの skill を使うか判断するため）。
- 本文（`SKILL.md`）は、その skill を実際に使ったときだけ読み込まれます。
- 一覧には上限があり、既定はコンテキストの 1% です。超えると、使われていない skill から説明文が削られます
  （`skillListingBudgetFraction` または環境変数 `SLASH_COMMAND_TOOL_CHAR_BUDGET` で変更できる）。
- 量は `/context` の Skills の行で確認できます。`/skill-doctor` を使うと、一度も使っていない skill や plugin が分かります。

## skill を絞る方法（3 系統）

### 1. 設定で skill ごとの見せ方を決める（`skillOverrides`）

`/skills` の画面で切り替えると `.claude/settings.local.json` に書かれます。どの設定ファイルにも書けます。

| 値                      | 効果                                                      |
| ----------------------- | --------------------------------------------------------- |
| `"on"`                  | 名前と説明を一覧に載せる（書かなかった skill もこの扱い） |
| `"name-only"`           | 名前だけ載せる。説明文の分のコンテキストが減る            |
| `"user-invocable-only"` | Claude からは見えない。`/名前` で手動でだけ使える         |
| `"off"`                 | Claude からも `/` メニューからも隠す                      |

Claude Code の plugin の skill には効きません（下の 2 で plugin ごと切り替える）。

### 2. plugin をプロジェクトごとにオン・オフする（`enabledPlugins`）

`"<plugin>@<marketplace>": true | false` を user（`~/.claude/settings.json`）・project（`.claude/settings.json`）・
local（`.claude/settings.local.json`）のどこにでも書けます。plugin ごとに、優先度の高い場所に書いた値が勝ちます
（local > project > user）。無効にした plugin の skill が一覧から消えることはドキュメントに明記されていないため、
`/context` で確認します。

### 3. skill 側の書き方で絞る

- `disable-model-invocation: true`（`SKILL.md` のフロントマター）: 説明ごとコンテキストから消え、`/名前` でだけ動く。
  `user-invocable: false` は `/` メニューから隠すだけで、コンテキストは減らない。
- `paths`（フロントマター）: 指定したパターンに合うファイルを触ったときだけ自動で読み込む。
- サブディレクトリの `.claude/skills/`: 起動時には読まれず、そのディレクトリのファイルを最初に読み書きしたときに読み込まれる。

APM で入れた upstream の skill はフロントマターを書き換えても更新で消えるため、3 は自作の skill（rulesync）でだけ使います。

そのほか、セッション単位で全部止めるなら `--disable-slash-commands`（skill とコマンドを全部無効）や `--bare`
（skill・plugin・MCP・CLAUDE.md の自動読み込みを止める）があります。

## 3 層に分けて管理する

| 層                         | 置き場所                                                                                | 役割                                                           |
| -------------------------- | --------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| 本体                       | `apm/apm.yml`・`config/rulesync/.rulesync/skills/` → `~/.claude/skills`                 | skill をインストールする。どのプロジェクトでも使える状態にする |
| 既定の見せ方               | `claude/settings.json`（`~/.claude/settings.json`）の `skillOverrides`                  | 普段の一覧を軽くしておく                                       |
| プロジェクトごとの切り替え | 各リポジトリの `.claude/settings.local.json`（commit しない）か `.claude/settings.json` | そのプロジェクトで使う skill だけ `"on"` に上げる              |

```jsonc
// 例: フロントエンドのリポジトリの .claude/settings.local.json
{
  "skillOverrides": {
    "html-prototype": "on",
    "html-wireframe": "on",
  },
}
```

> [!IMPORTANT]
> user とプロジェクトの両方に `skillOverrides` を書いたとき、skill ごとに合わさるのか、プロジェクト側で丸ごと
> 置き換わるのかはドキュメントで確認できていません。最初に 1 つのリポジトリで `/context` の Skills の行を見て
> 確かめてください。丸ごと置き換わる場合は、プロジェクト側にも全 skill を書く必要があります。

## 既定の設定（`claude/settings.json`）

| 値                    | skill                                                                                                                                                                                                                                         |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `on`                  | crit（`crit` / `crit-cli`）、`resolving-merge-conflicts`、ponytail（`ponytail` / `ponytail-*`）、`memo`、`planning`                                                                                                                           |
| `name-only`           | plannotator（`plannotator-review` / `-annotate` / `-last`）、effective-html（`html` / `html-*` / `design-artifact`）、`terminal-browser`、grill-me（`grill-me` / `grilling`）、`diagram-design`、`crit-pr`、`fix-review`、`review-pr`、`tmux` |
| `user-invocable-only` | 上以外（tsumiki の `dev-*` / `ipa-security-*` / `kairo-implement`、`ctx-agent-history-search`、`find-skills`、`article`、`coderabbit`、`deepwiki`、`suggest-rules`）                                                                          |

- 複数の skill をまとめて配る package（crit・ponytail・plannotator・effective-html・grill-me）は、package 単位で同じ値にしています。
  `crit-pr` は `crit` / `crit-cli` の使い方を前提にし、`grill-me` は `grilling` を呼び出すため、呼ばれる側を
  `user-invocable-only` にすると Claude から使えなくなります。
- `skillOverrides` に無い skill は `"on"` として一覧に載ります。`apm/apm.yml` や rulesync に skill を足したら、ここにも追加します。

## plugin の管理

Claude Code の plugin は、skill とは別に `enabledPlugins` で管理します。

| 種類                                                   | 例                                                  | 管理の仕方                                                                                                              |
| ------------------------------------------------------ | --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| 公式 marketplace（`claude-plugins-official`）の plugin | `frontend-design`                                   | marketplace は最初から登録済み。`enabledPlugins` に書いて有効にする                                                     |
| 他の marketplace の plugin                             | `expo-deployment@expo-plugins`                      | `/plugin marketplace add` で marketplace を足し、`enabledPlugins` に書く                                                |
| Claude Code 本体に同梱の skill（bundled）              | `/code-review`、`/simplify`、`/loop`、`/claude-api` | 普段は残す（使うときだけ本文が読まれる）。全部外すなら `disableBundledSkills`（`CLAUDE_CODE_DISABLE_BUNDLED_SKILLS=1`） |
| claude.ai のアカウント側の skill・plugin               | Web / cloud セッションの `anthropic-skills:*` など  | dotfiles では管理できない。claude.ai の設定で外す                                                                       |

方針:

- `claude/settings.json` の `enabledPlugins` は、どのプロジェクトでも使う plugin だけ `true` にする。
- 特定のプロジェクトでだけ使う plugin（例: Expo のリポジトリの `expo-deployment`）は、global を `false` にして、
  そのリポジトリの `.claude/settings.json`（チームで共有する）か `.claude/settings.local.json`（自分だけ）で `true` にする。

## 関連リンク

- [Skills（Claude Code）](https://code.claude.com/docs/en/skills)
- [Plugins の読み込み](https://code.claude.com/docs/en/plugins/loading)
- [Settings](https://code.claude.com/docs/en/settings)
