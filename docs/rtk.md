# rtk

[rtk](https://github.com/rtk-ai/rtk)（Rust Token Killer）は、`git`、`ls`、test runner、lintなどのコマンド出力を、AI agentのcontextへ入る前に圧縮するCLI proxyです。Claude CodeのPreToolUse hookでBashコマンドを`rtk <コマンド>`へ書き換え、要点（変更file、失敗したtest、errorなど）だけを返します。

codeburn（[`codeburn.md`](codeburn.md)）やAgentsView（[`agentsview.md`](agentsview.md)）が「どこでtokenを使ったか」を分析するのに対し、rtkは**Bash出力のtokenを実際に減らす**側のツールです。

## 導入

`config/mise/config.toml`で`aqua:rtk-ai/rtk`としてversionをpinしています。

```bash
mise install
rtk --version
```

hookは`PreToolUse`の`Bash` matcherで登録しています。正本はrulesyncのglobal source（`config/rulesync/.rulesync/hooks.json`の`claudecode.hooks.preToolUse`）で、`mise run rulesync:generate`で`~/.claude/settings.json`（＝`claude/settings.json`）へ生成されます。生成後の形は次のとおりです。

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "if command -v rtk >/dev/null 2>&1; then rtk hook claude; fi",
      "timeout": 5
    }
  ]
}
```

- `rtk init -g`は使いません。`~/.claude/settings.json`や`~/.claude/CLAUDE.md`を直接書き換えるため、このrepoの管理と衝突します。hookを変えるときは`config/rulesync/.rulesync/hooks.json`を編集して`mise run rulesync:generate`します（[`rulesync.md`](rulesync.md)）。
- `command -v rtk`で囲んでいるのは、rtkが入っていない環境（devcontainerなど、同じsettings.jsonを共有する場所）でBashのたびにhook errorを出さないためです。
- この書き方だとrtkは自分のhookを検出できず、`rtk gain`や`rtk discover`の先頭に`No hook installed — run rtk init -g`という警告が出ます（`rtk init --show`も「not found」と表示します）。書き換えは正しく動いているので、下の「設定file」にある`suppress_hook_warning = true`で警告を止めます。
- hookは書き換え後のコマンドを返すだけで、permissionの判定は変えません。
- telemetryは既定で無効です（`rtk telemetry status`で確認できます）。

hookを入れたあとはClaude Codeを再起動します。

## 何が変わるか

Claude CodeがBashで次のようなコマンドを実行すると、hookが自動で書き換えます。

| Claude Codeが実行したコマンド | 実際に実行されるコマンド | 出力の変化                          |
| ----------------------------- | ------------------------ | ----------------------------------- |
| `git status`                  | `rtk git status`         | branchと変更fileだけの短い形式      |
| `git log -n 3`                | `rtk git log -n 3`       | 1commit数行に要約し、長い本文は省略 |
| `ls -la`                      | `rtk ls -la`             | 一覧を圧縮                          |
| `cat README.md`               | `rtk read README.md`     | 不要部分を除いて読む                |
| `cargo test`、`pytest`など    | `rtk cargo test`など     | 失敗したtestとerrorだけ             |

Read、Grep、GlobなどClaude Code組み込みのtoolはBashを通らないため、書き換えの対象外です。

省略された出力が必要になった場合、rtkの出力に表示されるhashで元の出力を取り出せます（既定で30日、最大200件をlocalに保存）。

```bash
rtk recall --list          # 保存されている出力の一覧
rtk recall <hash>          # 省略された部分を表示
rtk recall <hash> --full   # 元の出力をすべて表示
```

## 効果を見る

```bash
# 削減したtoken数の合計とコマンド別の内訳
rtk gain

# 日別／週別／月別、ASCIIグラフ、履歴
rtk gain --daily
rtk gain --weekly
rtk gain --graph
rtk gain --history

# 現在のprojectだけ
rtk gain --project

# 圧縮に失敗して素の出力へfallbackしたコマンド
rtk gain --failures

# JSON／CSVで出す
rtk gain --format json
```

`rtk gain --quota --tier 20x`（`pro`／`5x`／`20x`）で、subscription planの月間枠に対してどれくらい節約できたかの目安も出せます。

## まだ削れるコマンドを探す

`rtk discover`は過去のClaude Code session log（`~/.claude/projects/`）を読み、rtkを通さずに実行された大きな出力のBashコマンドを洗い出します。session logは書き換えません。

```bash
rtk discover               # 現在のprojectの直近30日
rtk discover --all         # 全project
rtk discover --since 7     # 直近7日
rtk session                # 直近sessionごとのrtk利用率と出力量
```

`TOP UNHANDLED COMMANDS`に出るのは、rtkに専用filterがないコマンドです。頻度が高いものは、Claude Code側の指示（CLAUDE.mdやskill）で`--quiet`や`| tail`を使わせるか、codeburnの`optimize`の指摘とあわせて対策します。

## 書き換えを止める

1回だけ素の出力が欲しい場合は、コマンドの先頭に`RTK_DISABLED=1`を付けます。hookがそのコマンドを書き換えなくなります。

```bash
RTK_DISABLED=1 git log -n 3
```

特定のコマンドを常に書き換えの対象外にする場合は、rtkの設定fileに`exclude_commands`を書きます（次の「設定file」を参照）。

完全に止める場合は、`config/rulesync/.rulesync/hooks.json`から上記のhookを削除して`mise run rulesync:generate`します。

## 設定file

設定fileの場所はOSで異なります。`rtk config`の先頭に出る`Config:`のpathが、実際に読まれるfileです。

| OS    | path                                            |
| ----- | ----------------------------------------------- |
| macOS | `~/Library/Application Support/rtk/config.toml` |
| Linux | `~/.config/rtk/config.toml`                     |

既定では存在しないので、`rtk config --create`で作るか、直接書きます。このdotfilesでは設定fileをrepoで管理していません（macOSの保存先が`~/.config`配下ではないため）。

```toml
[hooks]
# 上記の「No hook installed」警告を出さない
suppress_hook_warning = true
# 常に書き換えない（素の出力を返す）コマンド
exclude_commands = ["git diff"]
```

設定fileを作らずに一時的に警告だけ止める場合は、環境変数`RTK_SUPPRESS_HOOK_WARNING=1`でも同じ効果があります。現在の設定は`rtk config`で確認できます。
