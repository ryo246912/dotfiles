# context-analyzer

[Context Analyzer](https://github.com/manavgup/context-analyzer)（PyPI package名は`context-tracker`）は、Claude Codeのsession logとhookの記録から、**1回のAPI呼び出しごとに、contextに何がどれだけ載っていたか**を分解するツールです。localのweb dashboardで、contextの増え方、tool別のtoken量、使われないまま載り続けている部分（dead weight）、cacheの読み直し量を見られます。

ほかのツールとの使い分けは次のとおりです。

| 知りたいこと                                                  | 使うもの                                       |
| ------------------------------------------------------------- | ---------------------------------------------- |
| 全端末の合計cost、project・model別の推移                      | AgentsView（[`agentsview.md`](agentsview.md)） |
| 作業種別・tool・Bashコマンド別のcost、設定の無駄の検出        | codeburn（[`codeburn.md`](codeburn.md)）       |
| 1つのsessionで、どのturn・どのtool結果がcontextを膨らませたか | context-analyzer（この文書）                   |
| Bash出力そのものを減らす                                      | rtk（[`rtk.md`](rtk.md)）                      |

## 導入

`config/mise/config.toml`で`pipx:context-tracker`としてversionをpinしています（Python 3.11以上。miseの`pipx`は`uvx = true`で`uv tool`経由で入ります）。

```bash
mise install
context-tracker --help
```

次の3つのコマンドが入ります。

| コマンド               | 用途                                           |
| ---------------------- | ---------------------------------------------- |
| `context-tracker`      | dashboard、統計の表示、MCP server              |
| `context-tracker-hook` | Claude Codeのhookから呼ばれ、eventを記録する   |
| `ccscope`              | 単体のcontext viewer（この文書では使いません） |

### hookの設定

READMEにある`context-tracker up`（hookの自動設定）は、PyPIで公開されている1.0.0にはまだありません。また、自動設定は`~/.claude/settings.json`を直接書き換えるため、このrepoの管理と衝突します。そのため、hookはrulesyncのglobal source（`config/rulesync/.rulesync/hooks.json`の`claudecode.hooks`）に登録し、`mise run rulesync:generate`で`~/.claude/settings.json`（＝`claude/settings.json`）へ生成しています（[`rulesync.md`](rulesync.md)）。

```json
{
  "command": "if command -v context-tracker-hook >/dev/null 2>&1; then context-tracker-hook; fi",
  "timeout": 10
}
```

- `command -v`で囲み、context-trackerが入っていない環境（devcontainerなど）では何もしないようにしています。
- 登録しているeventは、`PostToolUse`、`PreCompact`、`SessionStart`、`SessionEnd`、`SubagentStop`の5つです。
- context-tracker自身は`PostToolUseFailure`、`PostCompact`、`UserPromptSubmit`、`SubagentStart`、`InstructionsLoaded`にもhookを入れる設計です。しかし、pinしているrulesync 8.21.0はこれらをClaude Codeのevent名へ変換できないため、登録していません（`rulesync generate`が小文字のkeyのまま出力し、Claude Codeに無視されます）。この5つが無いと、tool失敗の回数、compaction後の記録、入力ごとの注意表示（nudge）、subagentの開始が取れません。token量の分析はsession log（`~/.claude/projects/`）から行うので、主な機能には影響しません。
- hookは1回あたり約0.4秒かかります（Pythonの起動時間）。tool呼び出しのたびに動くので、気になる場合はhooks.jsonから外してrulesync generateします。外してもsession logからの分析はできます。

hookを変えたあとは`mise run rulesync:generate`し、Claude Codeを再起動します。

### 記録される場所

| 場所                                      | 内容                                                                             |
| ----------------------------------------- | -------------------------------------------------------------------------------- |
| `~/.claude/context-trace/<session>.jsonl` | hookの記録。tool名、入力・出力の**文字数**など。promptやtool出力の中身は残さない |
| `~/.context-analyzer/analyzer.db`         | session logとhookの記録を取り込んだSQLite。dashboard起動時に自動で更新される     |

読むのは`~/.claude/projects/`（Claude Code）と`~/.codex/sessions/`（Codex）です。`~/.claude-account2`／`~/.claude-work3`の`projects`は`~/.claude/projects`へのsymlinkなので（[`ai.md`](ai.md)）、全accountのsessionが入ります。集計はlocalで完結し、外部へは送りません。

## 使い方

```bash
# dashboardを起動（http://127.0.0.1:8080 、Ctrl+Cで止める）
context-tracker dashboard
context-tracker dashboard --port 8081

# 全sessionの要約を表示
context-tracker stats
```

dashboardは`127.0.0.1`だけで待ち受けます。初回は全session logの取り込みに時間がかかります。グラフの描画にはChart.jsをCDN（jsdelivr）から読み込むので、offlineではグラフが表示されません。

### 単一sessionの画面（`/`）

上部のdropdownでsessionを選びます。

| panel                                   | 分かること                                                                                                  |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Peak resident                           | sessionで最大になったcontext量と、windowに対する割合                                                        |
| Cache-read churn                        | cacheから読み直したtokenの合計と、新規inputに対する倍率。同じcontextを何度も払っている量                    |
| Session cost／Health score／Tool errors | sessionのcost、健全性のscore、tool errorの率                                                                |
| Context growth                          | API呼び出しごとのcontext量の推移（system prefixと作業中の内容の積み上げ）。200K〜1Mの予算線を切り替えられる |
| Cache-read churn（グラフ）              | 呼び出しごとの読み直しtoken                                                                                 |
| Composition                             | contextの内訳。Tool I/O、Conversation、System prefix                                                        |
| Tools／Agents                           | tool別・subagent別のtoken量と回数                                                                           |
| Top growth turns                        | contextを最も増やしたturn                                                                                   |
| Dead weight                             | 古くなって使われていないのに、contextに残り続けている塊（tool結果やfile）                                   |
| Messages                                | 各turnの中身（prompt、tool呼び出し、tool結果、返答）                                                        |
| Recommendations                         | `/compact`や新しいsessionを勧める理由と、取り戻せるtoken量                                                  |
| Prompt efficiency                       | promptの具体性と、prompt1つあたりのcost                                                                     |

上部の**Optimize**（`/optimize`）はCLAUDE.mdの大きさと内容の診断です。

### 全sessionの画面（`/sessions`）

session数、API呼び出し数、cache read、cost、1呼び出しあたりのcostの合計と、**1呼び出しあたりのcost × peak context**の散布図、session一覧が出ます。一覧の行をclickすると単一sessionの画面へ移ります。

## tokenを多く使った箇所を調べる

### 考え方

Claude Codeは毎回のAPI呼び出しで、それまでの会話とtool結果をすべて送り直します（大半はcache readで安くなりますが、0ではありません）。そのため、tokenの使い方は次の3つで決まります。

1. **何が載っているか**: tool結果、会話、system prompt・CLAUDE.md・tool定義などの固定部分
2. **どれだけ大きいか**: 1つのtool結果やfileのtoken量
3. **何回載り直したか**: 大きなものが入ってから、compactionやsessionの終わりまでに続いたAPI呼び出しの数

context-analyzerは、この3つをsessionごとに分けて見せます。

### 手順

1. **`/sessions`で問題のsessionを探す**
   1呼び出しあたりのcostが高いsession、peak contextが大きいsessionを散布図と一覧で見つけ、clickして開きます。
2. **Context growthで膨らんだ場所を見る**
   グラフが急に上がっている呼び出しが、大きなものを取り込んだところです。上がったまま下がらない区間が長いほど、その後のすべての呼び出しで払い続けています。
3. **Top growth turnsで原因のturnを特定する**
   contextを最も増やしたturnが並びます。Messagesでそのturnを開くと、どのtool呼び出し（Bashのコマンド、Readしたfile）の結果だったかが分かります。
4. **Compositionで「何が」多いかを見る**
   Tool I/Oが大半なら、test出力・全体Read・検索結果などtool結果が原因です。System prefixが大きければ、CLAUDE.md・skill・MCP serverのtool定義など毎回載る固定部分が原因です。
5. **Toolsでtool別に比べる**
   tool別のtoken量と回数が出ます。回数が少ないのにtokenが大きいtool（大きな結果を返すBashやRead）が削る対象です。
6. **Dead weightで、もう要らないのに残っているものを見る**
   古いtool結果やfileで、以後使われていないのにcontextに残っているものが、大きい順に出ます。ここが大きいsessionは、早めの`/compact`や新しいsessionで減らせます。
7. **Cache-read churnで払い直しの量を見る**
   読み直し倍率が大きいほど、長いsessionで同じcontextを何度も払っています。
8. **Recommendationsを確認する**
   dead weightの割合などから、取るべき行動と取り戻せるtoken量が出ます。

### 見つかったものと対策

| 見つかったもの                                     | 対策                                                                                                          |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| test・lint・buildの出力でcontextが跳ねている       | 失敗だけを出すflagや`tail`へのpipeを使う指示をCLAUDE.mdやskillに書く。rtkで自動圧縮する（[`rtk.md`](rtk.md)） |
| 大きなfileの全体Read、同じfileの繰り返しRead       | Grepで位置を探してから範囲を指定してReadする                                                                  |
| System prefixが大きい                              | 使っていないMCP serverを外す、CLAUDE.mdを短くする、skillのdescriptionを短くする                               |
| Dead weightが大きい／contextが上がったまま長く続く | 調べ物はsubagentに任せて要約だけ戻す。作業の区切りで`/compact`するか新しいsessionにする                       |
| Cache-read churnの倍率が大きい                     | 1つのsessionに作業を詰め込みすぎない。話題が変わったらsessionを分ける                                         |

数字の出どころは、API呼び出しごとのtoken数（input・output・cache read・cache write）がsession logのAPI usage（実測値）です。block単位の大きさ（tool結果1つのtoken数など）は文字数からの推定です。

### 他のツールとの組み合わせ

- 全体の傾向（どのproject・どの作業種別が高いか）はcodeburnやAgentsViewで見て、気になるsessionをcontext-analyzerで掘り下げます。
- codeburnの`context <session>`（web版のContextタブ）でも、sessionのcontextの内訳を見られます。context-analyzerは、それに加えてturnごとの推移、dead weight、cacheの読み直しを見られます。

## MCP server（使わない）

`context-tracker`を引数なしで起動するとMCP server（stdio）になり、Claude Codeから「このsessionのcontextを何が占めているか」「`/compact`すべきか」などを問い合わせるtoolが12個使えます。ただしMCP serverを登録すると、そのtool定義が毎回のrequestに載り、それ自体がtokenを使います。このdotfilesでは登録しません。使う場合は、必要なprojectだけで一時的に`claude mcp add context-tracker -- context-tracker`します。
