# claude-trace

[claude-trace](https://github.com/badlogic/lemmy/tree/main/apps/claude-trace) は、Claude CodeとAnthropic APIの間のrequest／responseをそのまま記録するツールです。system prompt、tool定義、各turnで送ったmessage（tool結果を含む）、responseのusageが残るため、「1 requestに何が載っていて、どれが大きいのか」を直接確認できます。

session logから集計するAgentsViewやcodeburn（[`codeburn.md`](codeburn.md)）と違い、session logには残らない**固定overhead（system prompt・tool定義）の中身と大きさ**が見えるのが特徴です。

## 導入

`config/mise/config.toml`で`npm:@mariozechner/claude-trace`としてversionをpinしています。

```bash
mise install
```

### native binaryのClaude Codeでは動かない

claude-traceは`node --require <interceptor> <claudeのcli.js>`でClaude Codeを起動し、Node.jsの`fetch`を横取りして記録します。普段使っているClaude Code（`aqua:anthropics/claude-code`）は2.1.113以降native binaryになったため、nodeから読み込めず記録できません（[lemmy#48](https://github.com/badlogic/lemmy/issues/48)）。

そのため`local/bin/claude-trace-js`（`~/.local/bin`へ配置）を使います。最後のJS版である`@anthropic-ai/claude-code@2.1.112`を`~/.cache/claude-trace/claude-code-2.1.112/`へ初回だけinstallし、その`cli.js`を`--claude-path`に渡して`claude-trace`を起動します。auto updateで別版へ置き換わらないよう`DISABLE_AUTOUPDATER=1`も付けます。

```bash
# 素の claude-trace ではなく、必ず wrapper を使う
claude-trace-js
```

> [!IMPORTANT]
> 記録されるのは**2.1.112のClaude Code**の通信です。普段の版とはsystem prompt、tool一覧、挙動が異なるため、固定overheadの絶対値は目安として見ます。「どのtool結果が大きいか」「CLAUDE.md・skill・MCP serverがどれだけ載るか」といった、設定や使い方に由来する部分の比較に使います。versionを変える場合は`CLAUDE_TRACE_CLAUDE_VERSION=2.1.100 claude-trace-js`のように指定します（2.1.113以降は`cli.js`を含まないので不可）。

認証情報と設定（`~/.claude`、`CLAUDE_CONFIG_DIR`）は普段のClaude Codeと共有されます。別accountで記録する場合は`CLAUDE_CONFIG_DIR=~/.claude-account2 claude-trace-js`とします。2.1.112のsessionも`~/.claude/projects/`へ書かれるので、AgentsViewやcodeburnの集計にも入ります。

## 記録する

```bash
# 通常どおり対話で使う（終了するとHTMLが生成されてbrowserで開く）
claude-trace-js

# log名を付ける
claude-trace-js --log lint-fix

# claudeへ引数を渡す（--run-with 以降はすべてclaudeの引数）
claude-trace-js --run-with --model sonnet
claude-trace-js --no-open --run-with -p "README の typo を直して"

# 既定は messages が3件以上の /v1/messages だけを記録する。すべてのrequestを残す場合
claude-trace-js --include-all-requests
```

logは**実行したdirectoryの`.claude-trace/`**に`log-<日時>.jsonl`と`.html`で保存されます。`.claude-trace/`はglobal gitignore（`config/git/gitignore`）に入れてあり、commitされません。

> [!WARNING]
> logにはprompt、読み込んだfileの内容、コマンド出力がすべて平文で残ります。`Authorization`／`x-api-key` headerは伏せ字になりますが、bodyは伏せられません。秘密情報を扱うsessionでは使わず、不要になったlogは削除します。

## 見る

### HTMLで見る

終了時に生成されるHTMLを開くと、requestごとにsystem prompt、tool定義、messages、responseを展開して見られます。後からJSONLを変換し直すこともできます。

```bash
claude-trace --generate-html .claude-trace/log-2026-10-10-10-00-00.jsonl --no-open
```

`claude-trace --index`は`.claude-trace/`の全logの要約と一覧HTMLを作ります。要約は`claude -p`を呼んで生成するため、その分のtokenを消費します。

### requestごとのtoken内訳

`config/claude-trace/usage.jq`（`~/.config/claude-trace/usage.jq`へ配置）で、`/v1/messages`ごとに時刻、model、message数、tool定義数、input、cache read、cache write、outputをTSVで出します。streaming responseのSSEからもusageを読み取ります。

```bash
jq -r -f ~/.config/claude-trace/usage.jq .claude-trace/log-*.jsonl
```

cache writeが急に増えたrequestは、cacheが切れたかcontextが組み替わった（compaction、CLAUDE.mdやtool一覧の変化）ところです。cache readが単調に増えていくのは、それまでのtool結果を毎回読み直しているためです。

### contextに載っているtool結果を大きい順に

`config/claude-trace/context.jq`は、logの最後のrequestに載っていたtool結果を文字数の大きい順に並べ、どのtool呼び出し（Bashならコマンド、Readならfile path）の結果かを表示します。

```bash
jq -s -r -f ~/.config/claude-trace/context.jq .claude-trace/log-2026-10-10-10-00-00.jsonl | sort -rn | head -20
```

### 固定overhead（system prompt・tool定義）の大きさ

```bash
f=.claude-trace/log-2026-10-10-10-00-00.jsonl

# system promptの文字数
jq -s '[.[] | select(.request.url | test("/v1/messages"))][0].request.body.system | tostring | length' "$f"

# tool定義を大きい順に（MCP serverやskill由来のtoolが大きくないか）
jq -s -r '[.[] | select(.request.url | test("/v1/messages"))][0].request.body.tools[] | [(tojson | length), .name] | @tsv' "$f" | sort -rn | head -20
```

文字数からtokenへの換算は、英語・JSONで約4文字＝1token が目安です。ここが大きい場合は、使っていないMCP serverを外す、skillのdescriptionを短くする、CLAUDE.mdを分割する、などを検討します。

## 使いどころ

- codeburnの`context`やAgentsViewのSQL（[`agentsview.md`](agentsview.md)の「tool・コマンド単位でtoken効率を分析する」）で怪しいと分かった作業を、claude-trace-js上で再現して中身を確認する
- MCP server、skill、CLAUDE.mdの追加・削除の前後で、tool定義とsystem promptの大きさを比べる
- 常用はしない。普段のsessionはnative版で行い、調べたいときだけwrapperで起動する
