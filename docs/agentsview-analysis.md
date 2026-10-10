# agentsview 分析ガイド

AgentsViewでtoken使用量・cost・作業傾向を分析するときの「どこを見て、何を読み取るか」をまとめる。構築・運用手順は[agentsview.md](./agentsview.md)を参照。

内容は`config/agentsview/Dockerfile`でpinしているAgentsView 0.39.0のupstream docs（[agentsview.io](https://agentsview.io/)）に基づく。versionを上げたら画面やflagが変わっていないか確認する。

## まず「どのデータを見ているか」を決める

同じ数字でも、見る入口によって集計対象の端末が変わる。最初にここを間違えると「PCごとの合計と合わない」状態になる。

| 入口                                                   | 集計対象                                                       | 向いている用途                               |
| ------------------------------------------------------ | -------------------------------------------------------------- | -------------------------------------------- |
| Cloud Run上のWeb UI（`$AGENTSVIEW_CLOUD_RUN_URL`）     | CockroachDB Cloudへpush済みの**全端末**                        | 普段の分析。端末をまたいだ合計・比較         |
| `mise run agentsview:serve`（local CockroachDB）       | local CockroachDBへmergeした端末（dumpを取り込んだ分）＋このPC | Cloud Runを使わずに全端末をまとめて見る      |
| `agentsview usage daily`／`stats`などのCLI             | **このPCのlocal SQLite archiveだけ**                           | このPCの日次cost、scriptやstatuslineへの組込 |
| REST API（`/api/v1/usage/summary`など、Cloud Run経由） | Cloud Run UIと同じ（全端末）                                   | jqで加工したい、定期的に数値を取りたい       |

- Web UIのPG-backed表示（`pg serve`）はread-onlyで、SSEによる自動更新がない。最新値は各画面の**refresh**ボタンか期間変更で取り直す。数字が古いときは、まず各PCから`agentsview pg push`（または`agentsview:cockroach:push:remote`）されているかを疑う。
- CLIは`pg serve`を見ない。CLIの数字とCloud Run UIの数字が違うのは、CLIがこのPC分しか持っていないためで正常である。
- 端末ごとに分けたいときは、Web UIの**Machine**フィルタを使う。machine名は`templates/zsh/.zshenv.tera`で`HOST_ENV`から作っている。

## 画面の歩き方（Web UI）

ヘッダーから4つの画面に入れる。目的別に入口が違う。

| 知りたいこと                                     | 画面                       | URL                    |
| ------------------------------------------------ | -------------------------- | ---------------------- |
| いくら使ったか、何に使ったか（token・cost）      | **Usage**                  | `/usage`               |
| いつ・どれだけ並行して動かしたか、時間あたりcost | **Activity**               | `/activity`            |
| session数・tool利用・速度・健全性などの全体傾向  | **Dashboard**（Analytics） | `/`（session未選択時） |
| 特定sessionのtoken・cost・step内訳               | session詳細のheader        | sessionを開く          |

フィルタ状態はURLのquery parameterへ書き戻される。よく見る切り口はURLをbookmarkしておくと再現できる。**Settings > Date ranges > Link date ranges across pages**を有効にすると、Usage／Activity／Dashboardで期間が連動する。

### Usage画面: token使用量とcostの分析

token分析の中心。既定は直近30日。上部toolbarで期間、Project／Agent／Model（複数選択可）、Machineを絞り込む。

| panel                     | 見方                                                                                                                                                                                                     |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Summary cards             | Total Cost、total tokens、daily burn（1日平均）、peak day、cache hit rate、project／model数、active days。まずここで規模感をつかむ                                                                       |
| Cost Over Time            | 日別costの積み上げ。`Project`／`Model`／`Agent`で色分けを切り替える。急に跳ねた日を見つける                                                                                                              |
| Cost Attribution          | 期間合計の内訳をtreemap（または`List`）で表示。**cellをclickするとその項目を上のchartから隠せる**。大きいprojectを隠していくと、残りの小さい支出の行き先が見える                                         |
| Comparative Cost Analysis | 左右に`Project`か`Model`を1つずつ選び、total cost、session数、session当たりcost、token数、input／outputを差分付きで比較する。「projectAはBの何倍か」「modelを変えてsession当たりcostが下がったか」を見る |
| Top Sessions by Cost      | 期間内で高かったsession順。clickでtranscriptへ飛べるので、高い理由（長時間・巨大context・retry連発など）を直接確認する                                                                                   |
| Cache Efficiency          | cache read／cache write／cacheなしinput／outputの比率と、cacheなしの場合との差額（savings）。cache writeばかりでreadが少ない＝cacheを作っても再利用できていない                                          |

#### token列の読み方

| 列                        | 意味                                | 注意点                                                                    |
| ------------------------- | ----------------------------------- | ------------------------------------------------------------------------- |
| `INPUT`                   | cacheを使わずに送ったinput token    |                                                                           |
| `OUTPUT`                  | modelが生成したtoken                | 単価が最も高い。cost増の主因になりやすい                                  |
| `CACHE_CR`（cache write） | prompt cacheへ新しく書き込んだtoken | inputより割高。context compactionやprompt変更直後に増える                 |
| `CACHE_RD`（cache read）  | cacheから再利用したtoken            | 量は桁違いに多くなるが単価は安い。token総量を見て驚かず、cost側で判断する |

token「総量」はcache readが支配するので、**比較はcostかoutput tokenで行う**のが基本。costはLiteLLMの価格表（`model_pricing` table）から計算した推定値で、請求額そのものではない（subscription planでは実費と一致しない）。価格表にないmodelはcostが付かない。

### Activity画面: 時間と並行度の分析

既定は当日。`Day`／`Week`／`Month`／`Custom`で範囲を変え、Project／Agent／Machine／Automation（Interactive／Automated）で絞る。

- **Peak Concurrency**: 同時に動いていたagent数の最大値と、その時刻
- **Active**／**Agent-minutes**: 実際に動いていた壁時計時間と、並行agentの稼働分を合計した時間。並行で回すほどAgent-minutesがActiveより大きくなる
- **Concurrency chart**: 青がinteractive、橙がautomated。**Overlay**で`Tokens`か`Cost`を重ねると、どの時間帯に費用が出たかがわかる。bucketをclickするとその時間帯のsessionだけに絞れる
- **Breakdown**: `Agent-min`と`Cost`を切り替えてProject／Model／Agent別に並べる。「時間はかかっているがcostは小さい」「短時間だが高い」projectを見分ける

Total CostはUsage画面や`agentsview usage daily`と同じ日・同じtimezoneなら一致する（subagent・fork sessionも含めて重複除去済み）。

### Dashboard: 使い方の傾向

session未選択時のトップ画面。tokenではなく「どう使っているか」を見る。

| panel                      | 読み取れること                                                                         |
| -------------------------- | -------------------------------------------------------------------------------------- |
| Activity Heatmap           | 日別の利用量。cellをclickするとその日に全chartが絞られる                               |
| Hour of Week Heatmap       | 曜日×時間帯の利用。作業時間帯の偏り                                                    |
| Project Breakdown          | projectごとのsession／message数                                                        |
| Session Shape Distribution | session長、所要時間、autonomy（turnあたりtool call数）の分布                           |
| Tool Usage／Top Skills     | Read／Edit／Bash等のtool比率、skillの利用回数と推移                                    |
| Velocity Metrics           | turn cycle time、first response timeのp50／p90                                         |
| Agent Comparison           | agentごとのsession数・応答時間・tool利用                                               |
| Session Health             | health score、completed／erroredの数、tool失敗率、compaction回数（特に作業途中のもの） |

**Export CSV**でsummary／activity／projects／tools／velocityをまとめてCSV出力できる。ほかに**More → Trends**で任意の単語（例: `flaky`、`timeout`）の出現頻度の推移を描ける。

> [!NOTE]
> **More → Insights**（AIによる要約生成）はread-onlyの`pg serve`では無効。Cloud Run UIでは既存のinsightを見るだけになる。生成したい場合は、そのPCでlocalの`agentsview serve`を使う。

### session単位の分析

sessionを開くとheaderにinput／output tokenと推定cost（subagentがある場合は合計）が出る。step数をclickすると、prompt／usage eventごとのmodel、context size（input＋cache read＋cache write）、output token、step costが展開される。context sizeが急に膨らむstepやcompaction直後のcache writeを探すのに使う。

health gradeのbadgeをclickすると、score、outcome、tool失敗、context pressure、compactionの減点内訳が見られる。Session Vital Signs panelではtool種別ごとの所要時間と、遅かったtool callがわかる。

## よくある問いと見る場所

| 問い                        | 手順                                                                                                          |
| --------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 今月いくら使ったか          | Usageで期間を月初〜今日にし、Total Costを見る                                                                 |
| どのprojectが一番高いか     | Usage → Cost Attributionを`Project`に。上位を隠して残りも確認                                                 |
| model別の比率は             | Usage → Cost Over Time／Cost Attributionを`Model`に                                                           |
| PC別に分けたい              | Usage／ActivityのMachineフィルタで1台ずつ選ぶ                                                                 |
| 急にcostが跳ねた日の原因    | Cost Over Timeで日を特定 → 期間をその日に絞る → Top Sessions by Cost → transcriptとstep内訳を確認             |
| cacheが効いているか         | Usage → Cache Efficiencyのsavingsとcache hit rate。cache write比率が高いsessionはcompactionやprompt変更を疑う |
| 並行で回しすぎていないか    | Activity → Peak ConcurrencyとAgent-minutes、OverlayでCost                                                     |
| model変更・運用変更の効果   | Usage → Comparative Cost Analysisで`Model`同士、または期間を変えてsession当たりcostを比較                     |
| 自動実行（automated）のcost | ActivityのAutomationを`Automated`にしてBreakdownを`Cost`で見る                                                |

## CLIで見る（このPCの分だけ）

CLIはlocal SQLite archiveを読むので、このPCのsessionだけが対象。実行前に未取り込みのsession fileを自動でsyncする（`--no-sync`で省略）。

```sh
# 直近30日の日次cost（input／output／cache write／cache read／cost／model）
agentsview usage daily

# model別の内訳行を付ける
agentsview usage daily --breakdown

# 期間・agentを指定
agentsview usage daily --since 2026-10-01 --agent claude

# 今日のcostを1行で（tmuxやstarshipのstatusline向け）
agentsview usage statusline

# 今月の合計cost
agentsview usage daily --since "$(date +%Y-%m-01)" --json | jq '.totals.totalCost'

# 特定sessionのtokenとcost（session IDはWeb UIのURLや`agentsview session list`で取得）
agentsview session usage <session-id>

# 直近28日の利用傾向（session数、tool／model mix、cache economics、outcomeなど。experimental）
agentsview stats
agentsview stats --since 2026-10-01 --agent claude --format json

# 時間帯別の稼働・並行度・cost（Activity画面と同じreport）
agentsview activity report --preset week --date 2026-10-10
```

`--offline`を付けるとLiteLLMの価格表を取りに行かず、組込みのfallback価格で計算する。

## API で全端末の数字を取る

Cloud Run上のAPIはWeb UIと同じく全端末分を返す。bearer tokenはfnox経由で渡し、shellやhistoryへ出さない。

```sh
# 期間内のtotal（totalCost、各token数、cacheSavings）
fnox exec -- sh -c 'curl -fsS \
  -H "Authorization: Bearer $AGENTSVIEW_AUTH_TOKEN" \
  "'"$AGENTSVIEW_CLOUD_RUN_URL"'/api/v1/usage/summary?from=2026-10-01&to=2026-10-10&timezone=Asia/Tokyo"' \
  | jq '.totals'

# model別cost（高い順）
fnox exec -- sh -c 'curl -fsS \
  -H "Authorization: Bearer $AGENTSVIEW_AUTH_TOKEN" \
  "'"$AGENTSVIEW_CLOUD_RUN_URL"'/api/v1/usage/summary?from=2026-10-01&to=2026-10-10&timezone=Asia/Tokyo"' \
  | jq '.modelTotals | sort_by(-.cost) | .[] | {model, cost, outputTokens}'
```

`summary`は`agent`、`project`、`machine`、`model`などのquery parameterでUsage画面と同じ絞り込みができる。ほかに`/api/v1/usage/top-sessions`、`/api/v1/usage/pairwise-comparison`、`/api/v1/activity/report`、`/api/v1/analytics/*`、`/api/v1/trends/terms`がある。

## 数字が合わない・出ないとき

- **Cloud Run UIに最近のsessionがない**: そのPCからpushされていない。`agentsview pg status`でwatermarkを確認し、`mise run agentsview:cockroach:push:remote`を実行する（[agentsview.md](./agentsview.md)の「local dataとCockroachDBのpush／pull」）。
- **costが付かないsession／model**: そのmodelがLiteLLM価格表にない、またはagentがtokenをlocal logへ書いていない。AgentsViewはagentが書き出したtokenしか集計できない。
- **dashboardが`request timed out`になる**: 期間が長く、CockroachDBへの集計が重なっている。期間を短くして切り分ける。恒常的なら[agentsview.md](./agentsview.md)の`--write-timeout`の項を参照。
- **CLIとUIの合計が違う**: CLIはこのPCだけ、UIは全端末。UIでMachineをこのPCに絞ると近い値になる。
