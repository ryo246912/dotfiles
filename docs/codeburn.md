# codeburn

[CodeBurn](https://github.com/getagentseal/codeburn) は、AI coding agentのsession log（`~/.claude/projects/`のJSONLなど）をlocalで読み、token・costを**作業の種類（task category）・tool・Bashコマンド・MCP server・model・project**別に分解するCLIです。「どの使い方がtoken効率が悪いか」を見つけて直す`optimize`と、sessionのcontextの中身を分解する`context`があります。

AgentsViewとの使い分けは次のとおりです。

| 知りたいこと                                             | 使うもの                                                     |
| -------------------------------------------------------- | ------------------------------------------------------------ |
| 全端末の合計cost、project・model別の推移                 | AgentsView（Cloud Run UI。[`agentsview.md`](agentsview.md)） |
| 作業種別・tool・Bashコマンド別のcost、無駄の検出と修正案 | codeburn（このPCのsessionだけ）                              |
| Bashコマンドの出力そのものを減らす                       | rtk（[`rtk.md`](rtk.md)）                                    |

## 導入

`config/mise/config.toml`で`npm:codeburn`としてversionをpinしています。Node.js 22.13以上が必要で、miseの`core:node`で満たしています。

```bash
mise install
codeburn --version
```

読み込むのは`~/.claude/projects/`、Codex、Cursorなどの既定のlog置き場です。`~/.claude-account2`／`~/.claude-work3`の`projects`は`~/.claude/projects`へのsymlinkなので（[`ai.md`](ai.md)）、全accountのClaude Code sessionがまとめて集計されます。

価格表はLiteLLMから取得して`~/.cache/codeburn/`にcacheします。集計はlocalで完結し、session内容は外部へ送りません。ただし`share`／`devices`／`sync`は他端末やOTLP endpointへ送る機能なので、使う場合だけ明示的に設定します。

## まず見るもの

```bash
# 対話dashboard（既定は直近1週間。-p today|week|30days|month|all）
codeburn report
codeburn report -p 30days

# 今日／今月の概要を1画面で
codeburn today
codeburn month

# text 1枚の概要（copyしやすい）
codeburn overview
```

`report`のdashboardでは次の内訳が見られます。

| 区分                           | 内容                                                                                |
| ------------------------------ | ----------------------------------------------------------------------------------- |
| Activities（task category）    | debugging、feature、refactoring、testingなどの作業種別ごとのcostと**one-shot rate** |
| Tools                          | Bash、Read、Edit、Agentなどのtool別呼び出し数                                       |
| Shell commands                 | `npm`、`git`、`mise`などBashコマンド別の呼び出し数                                  |
| MCP servers／Skills／Subagents | MCP server、skill、subagent種別ごとの利用                                           |
| Models／Projects／Top sessions | model・project別costと高いsession                                                   |

one-shot rateは、編集を伴うturnが「Edit → Bash（testなど）→ 再Edit」のretryなしで終わった割合です。rateが低い作業種別は、指示が曖昧かtest・lintの往復が多く、tokenを無駄にしやすい箇所です。

数字をscriptで扱うときは`--format json`を付けます。

```bash
# Bashコマンド別の呼び出し数
codeburn report -p 30days --format json | jq '.shellCommands'

# 作業種別ごとのcostとone-shot rate
codeburn report -p 30days --format json | jq '.activities[] | {category, cost, oneShotRate}'
```

## ブラウザで見る

`codeburn web`でlocalのweb dashboardが起動し、browserが開きます。`report`のTUIと同じ内容を、グラフ付きで見られます。

```bash
codeburn web                 # 既定は今日。http://127.0.0.1:4747 で待ち受ける
codeburn web -p 30days       # 開いたときの期間
codeburn web --project dotfiles
codeburn web --port 4800 --no-open   # port指定、browserを自動で開かない
```

`127.0.0.1`だけで待ち受けるので、同じPCのbrowserからしか開けません。`Ctrl+C`で止めます。画面上部で`Usage`／`Context`の切り替え、期間（Today〜Lifetime）、`Cost`／`Tokens`の表示切り替え、agentの絞り込みができます。

| panel                             | 内容                                                                                |
| --------------------------------- | ----------------------------------------------------------------------------------- |
| Daily buckets                     | 日別（Today／7 daysでは時間別）のcost推移。`Sessions`／`Models`で色分けを切り替える |
| Cost／Tokens／Cache hit／One-shot | 期間の合計、cache read／writeの量、one-shot rate                                    |
| Top models／Model efficiency      | model別cost、編集1回あたりcostとone-shot rate                                       |
| Workflow                          | 修正のやり直し率（correction rate）、最初の編集までの時間、何度も編集し直されたfile |
| Spend punchcard                   | 曜日×時間帯のspend（Today／7 daysで表示）                                           |
| Top projects／By activity         | project別、作業種別（debugging、featureなど）別のcost                               |
| Subagents／Skills／MCP servers    | subagent種別、skill、MCP serverごとの利用                                           |
| Savings & waste                   | retryで余計にかかったcost（retry tax）など                                          |
| Tools                             | tool別の呼び出し数                                                                  |

`Context`では、`codeburn context`と同じくsessionを選んでcontextの内訳を見られます。

左のsidebarの**Share this device**／**Search local devices**は、他の端末と合計値を共有する機能です。このdotfilesでは端末をまたいだ集計はAgentsViewで行うので、onにしません。

## token効率の悪い使い方を見つける

### `optimize`: 無駄の検出と修正案

```bash
codeburn optimize                # 直近30日
codeburn optimize -p week
codeburn optimize --project dotfiles
```

設定や使い方ごとにfinding（例: Bash出力の上限が大きすぎる、同じfileの繰り返し編集が多いなど）を出し、推定削減token・cost、具体的な修正内容を示します。末尾の**Top reworked files**は、何度も編集し直されたfileです。

> [!WARNING]
> `codeburn optimize --apply`は`~/.zshrc`、`CLAUDE.md`、Claude Codeの設定などを直接書き換えます。このdotfilesでは`~/.claude/settings.json`や`~/.config`配下がrepoへのsymlinkで、shell設定もrepoで管理しているため、`--apply`は使いません。findingの内容を見て、repo側（`claude/settings.json`、`templates/zsh/`、`rulesync`の元ファイルなど）を手で直してcommitします。どうしても試す場合は`--apply --dry-run`で変更内容だけを確認し、適用したものは`codeburn act`で確認・取り消せます。同じ理由で、Claude Codeへhookを入れる`codeburn guard`も使いません。

### `context`: contextを何が埋めているか

```bash
# 最近のsessionを一覧から選ぶ
codeburn context

# session IDを指定（IDは codeburn context --list や AgentsViewのURLで確認）
codeburn context <session-id>

# compaction前も含めたsession全体
codeburn context <session-id> --full
```

最後のturnのcontext量（API usageからの実測値）と、そのうちsystem prompt・tool定義・memoryが占める量、残りをrole（assistant／user／tool）、block種別、tool別に分けて表示します。`tool-result`が大部分なら、test出力や全体Readなど大きいtool結果が原因です。system prompt・tools・memoryが大きい場合は、CLAUDE.md、skill、MCP serverの数を見直します。block単位の値は文字数/4による推定です。

### その他の切り口

```bash
# sessionごとのcost一覧
codeburn sessions -p 30days --no-pager

# model別。--by-taskで作業種別ごと、--by-agentでsubagent種別ごと
codeburn models -p 30days --by-task

# 期間Aと期間Bの比較（設定変更の前後比較など）
codeburn compare-periods --from-a 2026-09-01 --to-a 2026-09-15 --from-b 2026-09-16 --to-b 2026-09-30

# spendがmainにmergeされたcommitにつながったか（experimental）
codeburn yield -p 30days

# 生のtoken値とcodeburnのcost計算の照合（数字が怪しいとき）
codeburn audit

# CSV／JSONで書き出す
codeburn export
```

## 改善の進め方

1. `codeburn report -p 30days`で、costの大きい作業種別とone-shot rateの低い作業種別を確認する
2. `codeburn optimize`でfindingを確認し、repo側の設定（CLAUDE.md、skill、settings）へ反映してcommitする
3. 気になるsessionを`codeburn context <id>`で開き、contextを埋めているtool結果を確認する。transcriptはAgentsViewで開く
4. 1〜2週間後に`codeburn compare-periods`で変更前後を比べる

## 数字が出ない・合わないとき

- `codeburn doctor`で、各agentのlog pathが見つかっているか、parse errorがないかを確認する。
- costはAPI単価で計算した推定値で、subscription planの実費ではない（`codeburn plan`で登録すると超過分の見積もりもできる）。
- 集計対象はこのPCのlogだけ。端末をまたいだ合計はAgentsViewで見る。
