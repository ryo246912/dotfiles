# mcpc で MCP を使う

[mcpc](https://github.com/apify/mcpc) は MCP の操作をシェルコマンドとして提供する CLI client です。この dotfiles では
**MCP サーバをどの agent の native MCP にも登録せず、mcpc から必要な時だけ使います**。MCP サーバの定義とバージョンは
APM（[`docs/apm.md`](apm.md)）の書式で管理します。

## なぜ mcpc を使うのか（コンテキスト節約の仕組み）

agent（Claude Code など）の native MCP に server を登録すると、起動時に全 tool の定義（名前・説明・引数の JSON Schema）が
system prompt に入り、使わない会話でもコンテキストを消費し続けます。server を足すほど毎回の会話が重くなります。

mcpc では MCP サーバを agent の設定に登録しません。

1. MCP サーバの定義は、agent が読まない mcpc 専用の config にだけ置く。agent は起動時に MCP を何も読み込まない。
2. 必要になったら agent が Bash で `mcpc connect <config>:<server> @<session>` を実行する。mcpc の bridge process が
   server との接続を保持し、agent にはコマンドの出力だけが返る。
3. `mcpc grep` で tool 名を探し、`tools-get` で使う tool の schema だけを読み、`tools-call` で実行する。
   コンテキストに入るのはこの出力だけ。
4. 作業後は `mcpc close @<session>` で閉じる。

## 全体像

```
config/mcpc/mcp.yml, mcp.<env>.yml        … MCP の定義（APM の dependencies.mcp 書式）
        │ mise run apm:install（apm:install-mcpc）
        ▼
~/.local/state/mcpc/apm-home/.copilot/mcp-config.json   … host / devcontainer 用（stdio は command、remote は url）
~/.config/mcpc/sandbox/mcp-config.json             … sandbox 用（host の mcpc proxy の URL だけ）
        │
        ├─ host          : mcpc connect <host 用 config>:<server> @<session>
        ├─ devcontainer  : 同上（config を read-only mount）
        ├─ sandbox（既定）: host の `mise run sandbox:mcpc` が mcpc proxy を立て、sandbox 内の mcpc から接続
        └─ sandbox（オプション）: `mise run sandbox:add-mcp` で sbx に add し、sandbox の gateway に load して agent の native MCP として使う
```

| 経路                         | MCP サーバが動く場所 | agent のコンテキスト         | credential                               |
| ---------------------------- | -------------------- | ---------------------------- | ---------------------------------------- |
| host                         | host                 | `mcpc` の出力だけ            | host（mcpc の keychain / host の設定）   |
| devcontainer                 | container            | `mcpc` の出力だけ            | container 内で認証する                   |
| sandbox：mcpc proxy（既定）  | host                 | `mcpc` の出力だけ            | host に留まる（proxy の token だけ渡す） |
| sandbox：sbx gateway（任意） | host                 | 載せた server の全 tool 定義 | host に留まる（sbx が送信時に注入）      |

認証の詳細は [認証のパターン](#認証のパターン) にまとめています。

## MCP の定義と管理

定義は `config/mcpc/mcp.yml`（共通）と `config/mcpc/mcp.<env>.yml`（work2 / work3 / private など。gitignore 済み、
雛形は `mcp.<env>.yml.example`）に、APM の `apm.yml` の `dependencies.mcp` と同じ書式で書きます。mcpc 経路と
sbx gateway 経路の両方がこのファイルを読みます。`apm/apm.yml` の `dependencies.mcp` は空のままです
（[`docs/apm.md`](apm.md#mcp-サーバ)）。

```yaml
dependencies:
  mcp:
    - name: notion # remote（OAuth は mcpc login）
      registry: false
      transport: http
      url: https://mcp.notion.com/mcp
    - name: context7 # stdio（パッケージは <package>@<version> で固定）
      registry: false
      transport: stdio
      command: npx
      args: ["-y", "@upstash/context7-mcp@4.3.0"]
```

- すべて self-defined（`registry: false`）で書きます。registry 参照は解決後のコマンドが残らないため使えません。
- stdio はパッケージを `args` の `<package>@<version>` で固定します。`mcp.yml` は Renovate が `npx`（npm）/
  `uvx`（PyPI）の新しいバージョンで更新します（`command` の直後に `args` を書いたものが対象）。
- credential は書きません。認証は OAuth か、server 自身が読む host の設定（`~/.aws` の profile など）に任せます
  （[認証のパターン](#認証のパターン)）。shell の環境変数で credential を渡す server（Slack の token、
  aws-vault の一時 credential を使う AWS Labs の server など）は今は扱っていません。
- `sbx_options` は sbx gateway 経路だけで使う独自キーです（`--dir` / `--skip-ssrf-check` など）。APM は
  警告を出して保持するだけで、mcpc は無視します。
- 同じ name を複数のファイルに書いた場合は先に読んだ方（`mcp.yml` → `mcp.<env>.yml` の順）を使います。
- 環境別のファイルを置いたら `mise bootstrap dotfiles apply` で `~/.config/mcpc` へ配置し、`mise run apm:install` します。
- 以前の `config/sbx/mcp.<env>.yml` は読みません。残っている場合は `apm:install-mcpc` が警告するので、
  `git mv` ではなく（gitignore 済みのため）`mv -i config/sbx/mcp.<env>.yml config/mcpc/` で移動してから上を実行します
  （移動先に同じ名前のファイルがあれば上書きせず、中身をまとめてください）。

## mcpc の設定の仕組み（apm:install-mcpc）

`mise run apm:install`（と `apm:ci`）の最後に `apm:install-mcpc` が次を行います。

1. `~/.config/mcpc/mcp.yml` と `mcp.<env>.yml` の `dependencies.mcp` を yq / jq で 1 つにまとめ、mcpc 専用の
   manifest（`~/.local/state/mcpc/apm-home/.apm/apm.yml`）を毎回作り直す。
2. その manifest を、HOME を `~/.local/state/mcpc/apm-home` に隔離して `apm install -g --only mcp --target copilot` する。
   APM は Copilot CLI 形式の config（`<HOME>/.copilot/mcp-config.json`）を書くので、隔離した HOME の下にだけ
   生成され、実際の `~/.copilot` や `~/.claude.json` には何も登録されない。生成物は `~/.config`（mise の history で
   丸ごと track している）を避けて `~/.local/state` に置く（devcontainer の mount と揃えるため `XDG_STATE_HOME` には
   追従しない固定パス）。
3. 各 server に host の port（`MCPC_PROXY_PORT_BASE`、既定 8931 から）を割り当て、sandbox 用の config
   （`~/.config/mcpc/sandbox/mcp-config.json`）を書く。中身は `http://host.docker.internal:<port>` と
   `Authorization: Bearer ${MCPC_PROXY_TOKEN}` だけで、credential は含まない。既存の server は前回の port を
   引き継ぎ、新しい server にだけ空いている port を振る（server を消しても他の server の port はずれない）。
   定義から消した server の proxy（`@sbx-<name>`）はここで止める。

`~/.apm/apm.yml` とは別の manifest なので、MCP は `apm/apm.lock.yaml` に載らず、`apm:ci` の `--frozen` とも独立しています。
定義ファイルや生成物が変わると `apm:sync`（`mise bootstrap` の hook）が `apm:install` をやり直します。

## 認証のパターン

どの経路でも credential は `config/mcpc/mcp*.yml` に書かず、MCP サーバを動かす側（host か devcontainer）にだけ置きます。
sandbox の VM には MCP サーバの credential を入れません。

server ごとの認証方式は次のとおりです。

| server の種類                   | 例                              | 認証の仕方                                                                |
| ------------------------------- | ------------------------------- | ------------------------------------------------------------------------- |
| 認証なし                        | deepwiki / context7             | 何もしない                                                                |
| remote の OAuth                 | notion / metabase               | 経路ごとに 1 回ブラウザで認可する（mcpc と sbx で別々に保存される）       |
| `mcp-remote` 経由の OAuth       | datadog                         | 初回接続時にブラウザで認可。token は `mcp-remote` が `~/.mcp-auth` に保存 |
| host の設定を server 自身が読む | aws-mcp（`--profile`）          | `~/.aws/config` の profile で認証できる状態にしておく                     |
| host で動いている app に繋ぐ    | figma-desktop / chrome-devtools | app を起動しておく（認証は app 側）                                       |

### mcpc 経路（既定）

MCP サーバは host（devcontainer なら container）で mcpc が起動します。sandbox 内の mcpc は host の proxy に繋ぐだけで、
MCP サーバの credential は持ちません。

| 場所           | 認証するもの                          | コマンド                                                                        | ファイル・環境変数                                                                                           |
| -------------- | ------------------------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| host           | remote の OAuth（server ごとに 1 回） | `mcpc login <url>`（例: `mcpc login https://mcp.notion.com/mcp`）               | token は OS の keychain（mcpc が管理。`mcpc --json` の `profiles` で一覧を確認、`mcpc logout <url>` で削除） |
| host           | `mcp-remote` の OAuth                 | 初回の `mcpc connect`（または `sandbox:mcpc`）でブラウザが開く                  | `~/.mcp-auth`                                                                                                |
| host           | aws-mcp                               | なし（profile で認証できる状態にする）                                          | `~/.aws/config`                                                                                              |
| host → sandbox | proxy の bearer token                 | `mise run sandbox:mcpc <server>...`（token が無ければ作る）                     | host: `~/.local/state/mcpc/proxy-token`（`0600`）                                                            |
| sandbox        | なし（token は `sbx-agent` が渡す）   | `mcpc connect "$MCPC_SANDBOX_CONFIG:<server>" @<server>`                        | env: `MCPC_PROXY_TOKEN` / `MCPC_SANDBOX_CONFIG`、mount: `~/.config/mcpc/sandbox`（read-only）                |
| devcontainer   | remote の OAuth                       | container 内で `mcpc login <url>`（host の keychain は container から見えない） | config: `~/.local/state/mcpc/apm-home/.copilot/mcp-config.json`（read-only mount）                           |

sandbox で使うまでの流れ:

```bash
# host（初回だけ）
mise run apm:install                          # config/mcpc/mcp*.yml から mcpc 用 config を生成
mcpc login https://mcp.notion.com/mcp          # remote の OAuth（server ごと）

# host（使うとき）
mise run sandbox:mcpc notion metabase         # server ごとに mcpc proxy を起動（host の credential で接続）
sbx-agent claude                              # token と sandbox 用 config を sandbox に渡して起動

# sandbox 内
mcpc connect "$MCPC_SANDBOX_CONFIG:notion" @notion
```

- proxy は起動時の host の credential で server に接続し、sandbox からの要求を中継します。sandbox 側には
  OAuth token も HTTP header も渡りません。
- `MCPC_PROXY_TOKEN` は sandbox の作成時に渡ります。token を作り直した（`proxy-token` を消した）ら sandbox も作り直します。
- OAuth の token が切れた・アカウントを替えたときは、host で `mcpc login <url>` し直し、`mise run sandbox:mcpc <server>`
  で proxy を張り直します。

### sbx gateway 経路（オプション。以前の `sandbox:mcp` の経路）

以前は `mise run sandbox:mcp` で sbx に登録し、`sbx-agent` が起動時に全 server を gateway に load していました。今は
登録が `sandbox:add-mcp`、load が起動後の `sandbox:load-mcp` に分かれ、起動時には何も load しません。認証の仕組みは
以前と同じで、MCP サーバの credential は sbx が host で持ち、送信時に注入します。

| 場所    | 認証するもの                          | コマンド                                                                                  | ファイル・保存先                                                                         |
| ------- | ------------------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| host    | remote の OAuth（server ごとに 1 回） | `mise run sandbox:add-mcp`（`sbx mcp add --url` の初回にブラウザで認可）                  | token は host の OS keychain（sbx が管理）。登録の記録は `~/.local/state/sbx-mcp/<name>` |
| host    | header の値（`headers` の `${VAR}`）  | `sbx secret set <VAR>`（`headers` に書いた `${VAR}` は sbx の secret として解決される）   | sbx の secret store（`sbx secret ls`）                                                   |
| host    | `mcp-remote` の OAuth                 | 初回の接続時にブラウザで認可                                                              | `~/.mcp-auth`                                                                            |
| host    | aws-mcp                               | なし（profile で認証できる状態にする。`sbx_options` の `--dir` で作業ディレクトリを指定） | `~/.aws/config`                                                                          |
| sandbox | なし                                  | `mise run sandbox:load-mcp`（host で実行。sandbox と server を fzf で選ぶ）               | agent の接続先は `http://mcp-gateway.docker.internal/mcp`（sbx が自動で設定する）        |

sandbox で使うまでの流れ:

```bash
# host（初回・定義を変えたとき）
mise run sandbox:add-mcp                      # sbx mcp add。remote は初回だけブラウザで認可
sbx mcp ls                                    # 登録を確認

# host（使うとき）
sbx-agent claude                              # 起動（MCP は load しない）
mise run sandbox:load-mcp                     # 必要な server だけ gateway に load

# sandbox 内
claude mcp list                               # gateway 経由で tool が見えるか確認
```

- `sbx mcp rm <name>` で登録を消すと、その server の OAuth の token も消えます。再登録すると認可をやり直します。
- mcpc と sbx は OAuth の token を別々に保存します。両方の経路を使うなら、それぞれで認可します。

## host で使う

```bash
mcpc connect ~/.local/state/mcpc/apm-home/.copilot/mcp-config.json:notion @notion
mcpc @notion tools-list
mcpc close @notion
```

## sandbox で使う：mcpc proxy（既定）

sandbox（[`docs/docker-sandboxes.md`](docker-sandboxes.md)）では credential を VM に入れず、MCP サーバは host で動かします。

```
[host]    mise run sandbox:mcpc notion metabase
            └─ mcpc connect <host 用 config>:notion @sbx-notion --proxy 127.0.0.1:8934 --proxy-bearer-token <token>
                 └─ notion の remote MCP（OAuth token は host の keychain）
[sandbox] mcpc connect "$MCPC_SANDBOX_CONFIG:notion" @notion
            └─ http://host.docker.internal:8934（Authorization: Bearer $MCPC_PROXY_TOKEN）
```

仕組み:

- `mise run sandbox:mcpc <server>...` は、指定した server ごとに host で `mcpc connect ... --proxy 127.0.0.1:<port>` を
  実行する。mcpc の bridge が server との session を持ち、その session を新しい MCP サーバとして `127.0.0.1:<port>` に
  公開する（mcpc の [MCP proxy](https://github.com/apify/mcpc#mcp-proxy) 機能）。proxy の利用者には元の OAuth token や
  HTTP header を渡さない。
- stdio / remote のどちらも同じ方法で中継できる。bridge はバックグラウンドで動き続け、`mise run sandbox:mcpc-stop` で止める。
  起動し直すと、その時の host の credential で接続し直す。
- proxy は bearer token を要求する。token は host の `${XDG_STATE_HOME:-~/.local/state}/mcpc/proxy-token`（`0600`）にあり、
  `sandbox:mcpc` と `sbx-agent` のどちらかが最初に作る。`sbx-agent` が `MCPC_PROXY_TOKEN` として sandbox に渡し、
  sandbox 用 config の `${MCPC_PROXY_TOKEN}` を mcpc が展開する。token の値は config ファイルには書かない。
- `sbx-agent` は sandbox 用 config（`~/.config/mcpc/sandbox`）を read-only で mount し、そのパスを `MCPC_SANDBOX_CONFIG` で
  渡す（sandbox 内の `$HOME` はホストと別物のため）。config を生成する前に作った sandbox は作り直す。
- sbx のプロキシは `host.docker.internal` を host の localhost へ転送するため、`sandbox:mcpc` が network policy に
  `localhost:<port>` を追加する。
- sandbox 内の agent の native MCP には何も載らない。`sbx-agent` は既定で gateway から何も読み込まない。

```bash
# host（初回は mise run apm:install と mise run sandbox:build-template も）
mise run sandbox:mcpc notion metabase
mise run sandbox:mcpc            # 引数なしで server と port の一覧
mise run sandbox:mcpc-stop       # 全 proxy（mcpc の @sbx-* session）を止める
```

```bash
# sandbox 内
mcpc connect "$MCPC_SANDBOX_CONFIG:notion" @notion
mcpc grep -E 'page|search'
mcpc close @notion
```

## sandbox で使う：sbx gateway（オプション）

agent の native MCP として使う経路に戻すための口です。tool の定義が agent のコンテキストに常に入るため、既定では使いません。

```bash
mise run sandbox:add-mcp       # add: config/mcpc/mcp*.yml を host の sbx に登録（一度だけ）
sbx-agent claude               # sandbox を起動（MCP は何も load しない）
mise run sandbox:load-mcp      # load: 必要な server だけ、起動後に sandbox の gateway へ（fzf で選ぶ）
```

仕組み（add と load の 2 段階）:

| 段階 | コマンド                                               | 範囲                        | コンテキストへの影響              |
| ---- | ------------------------------------------------------ | --------------------------- | --------------------------------- |
| add  | `sbx mcp add`（`mise run sandbox:add-mcp`）            | host 全体の登録簿。一度だけ | なし                              |
| load | `mise run sandbox:load-mcp`（起動後に `sbx mcp load`） | 特定の sandbox の gateway   | ここで tool の定義が agent に入る |

- gateway は sandbox ごとの MCP の窓口（host の sandboxd 内の HTTP listener。sandbox からは
  `http://mcp-gateway.docker.internal/mcp`）で、load した server だけを 1 つの endpoint にまとめて中継する。
- add は `sbx mcp add` で host の sbx に server を登録する。stdio は host で起動され、remote は host から接続される。
  OAuth token や API キーは host の OS keychain に入り、sbx のプロキシが送信時に注入する。
- load は起動後の sandbox に `sbx mcp load` で add 済みの server を読み込む。`sbx-agent` は起動時に何も load
  しない（必要な server だけを後から足し、使わない tool の定義をコンテキストに入れないため）。sandbox 内の agent は
  gateway（`http://mcp-gateway.docker.internal/mcp`）だけに MCP として接続し、読み込んだ server の全 tool が
  native MCP として見える。`mise run sandbox:load-mcp` は sbx の TUI に MCP を load する操作が無いため用意した task で、
  sandbox と server を fzf で選んで `sbx mcp load <name> --sandbox <sandbox>` を実行する。
  接続中の agent には MCP の `tools/list_changed` 通知で新しい tool が伝わる（反映するかは agent 次第）。
- template の Claude Code の managed settings（`config/devcontainer/claude/mcp-policy.sandbox.json`）は URL の
  server だけを許可しており、gateway は通る（stdio は止まる）。

`sandbox:add-mcp` は `registry: false` のエントリを次のように `sbx mcp add` の引数へ変換します。

| mcp.yml                         | sbx mcp add                                            |
| ------------------------------- | ------------------------------------------------------ |
| `transport: http` / `sse` + url | `--url <url>`（`headers` は `--header 'Name: value'`） |
| `transport: stdio` + command    | `--command <command> --args <args を , で連結>`        |
| stdio の `env`                  | `--command env --args K=V,...,<command>,<args>` で包む |
| `sbx_options`（独自キー）       | `sbx mcp add` の末尾にそのまま追加（`--dir` など）     |

- 登録した定義を `~/.local/state/sbx-mcp/<name>` に記録し、変わった server だけ `sbx mcp rm` → `sbx mcp add` で
  登録し直す（remote は OAuth の認可をやり直すことがある）。
- remote の URL にクエリを付けると OAuth 検出が失敗するため、クエリが必要な server は `mcp-remote` を stdio として
  書く（`mcp.work3.yml.example` の datadog）。
- `--args` は `,` 区切りなので、`,` を含む引数・env はエラーにする。
- `mcp*.yml` から消した server は自動では消さない。不要なら `sbx mcp rm <name>`。

### tool の定義はいつコンテキストに入るか

**`sbx mcp add` だけではコンテキストに入りません。** host の sbx に登録するだけです。

**sandbox の gateway に読み込んだ時点で、ツール定義が毎回コンテキストに入ります。** 読み込みは `sbx mcp load`
（`mise run sandbox:load-mcp`）で起きます。agent は MCP クライアントとして gateway に接続し、
`tools/list` で全ツールの定義を受け取ります。その定義が system prompt に入るので、使わない会話でも毎回消費します。

**proxy してもツール定義の入り方は変わりません。** gateway がしているのは「server を host で動かし、credential を
隠して中継する」ことだけです。ツール定義を減らす仕組みではありません。agent が MCP クライアントとして接続する限り、
普通に MCP を登録した場合と同じだけコンテキストを使います。

**mcpc proxy ではここが違います。** agent は MCP クライアントにならず、Bash で `mcpc` を実行するだけなので、
コンテキストに入るのは `mcpc` の出力だけです。

> [!NOTE]
> 上は agent が受け取ったツール定義をそのまま system prompt に入れる場合の挙動です。Claude Code の MCP tool search の
> ように、agent 側で定義を遅延読み込みする機能があると、system prompt に入るタイミングや量は agent / version によって
> 変わります。このリポジトリではその機能を前提にせず、定義を agent に渡さない mcpc 経路を既定にしています。

### 新しい MCP を追加する手順（sbx gateway）

1. 定義を書く。共通なら `config/mcpc/mcp.yml`、work3 などの環境だけなら `config/mcpc/mcp.<env>.yml`
   （無ければ `mcp.<env>.yml.example` をコピー。gitignore 済み）に `registry: false` で追加する。

   ```yaml
   # remote（HTTP）
   - name: linear
     registry: false
     transport: http
     url: https://mcp.linear.app/mcp
   # stdio（パッケージは <package>@<version> で固定）
   - name: example
     registry: false
     transport: stdio
     command: npx
     args: ["-y", "example-mcp-server@1.2.3"]
     sbx_options: ["--dir", "/path/to/workdir"] # 必要なときだけ
   ```

   - credential は値を書かない（[認証のパターン](#認証のパターン)）。
   - URL にクエリが必要な remote は `mcp-remote` を stdio として書く（`mcp.work3.yml.example` の datadog）。
   - `127.0.0.1` で動く host のサーバは `sbx_options: ["--skip-ssrf-check"]` を付ける。

2. `mcp.<env>.yml` を新しく置いた場合は `mise bootstrap dotfiles apply` で `~/.config/mcpc` に配置する。
3. host で sbx に add する（remote は初回だけブラウザで OAuth の認可が開く）。

   ```bash
   mise run sandbox:add-mcp
   sbx mcp ls          # 登録されたか確認
   ```

4. sandbox の gateway に load する。

   ```bash
   mise run sandbox:load-mcp                       # 起動済みの sandbox に足す（sandbox と server を fzf で選ぶ）
   mise run sandbox:load-mcp <sandbox> linear      # 指定して足す
   ```

5. sandbox 内で `claude mcp list` を実行し、gateway 経由で tool が見えることを確認する。

同じ定義は mcpc からも使えます（`mise run apm:install` で mcpc 用 config に入り、`mise run sandbox:mcpc <name>`
で proxy できる）。定義を変えたら `mise run sandbox:add-mcp` を再実行すると、変わった server だけ登録し直します。

## sandbox の 2 経路の比較

| 観点                 | mcpc proxy（既定）                                         | sbx gateway（オプション）                             |
| -------------------- | ---------------------------------------------------------- | ----------------------------------------------------- |
| agent のコンテキスト | `mcpc` の出力だけ                                          | 読み込んだ server の全 tool 定義が常に入る            |
| agent からの使い方   | Bash で `mcpc connect` / `grep` / `tools-call`             | native MCP の tool として直接呼ぶ                     |
| server が動く場所    | host（mcpc の bridge）                                     | host（sbx）                                           |
| credential           | host に留まる（mcpc の keychain / 起動した shell の環境）  | host に留まる（sbx の keychain / host の環境）        |
| remote の OAuth      | `mcpc login <url>`                                         | `sbx mcp add --url` の初回認可                        |
| sandbox からの接続先 | `host.docker.internal:<port>`（server ごと、bearer token） | `mcp-gateway.docker.internal`（1 つに集約）           |
| 起動・停止           | `sandbox:mcpc` / `sandbox:mcpc-stop` で必要な時だけ        | 登録は常駐。sandbox 作成時・`sbx mcp load` で読み込み |
| 必要な許可           | network policy の `localhost:<port>`                       | 不要（sbx の gateway）                                |

### 単体の mcp-proxy を使わない理由

[sparfenyuk/mcp-proxy](https://github.com/sparfenyuk/mcp-proxy) も stdio の server を HTTP で公開できますが、次の理由で
mcpc 自身の proxy にしています。

- named server は stdio だけで、remote（Notion / Metabase / deepwiki など）を中継できない。
- proxy に認証が無い（mcpc は bearer token を要求できる）。
- config の `${VAR}` を展開しないため、別に env を外した config を作る必要がある。
- 指定した server を起動時にすべて立ち上げ、1 つでも失敗すると止まる。

## 経路を切り替える

どちらの経路も定義（`config/mcpc/mcp*.yml`）は共通なので、切り替えはコマンドと環境変数だけで済みます。
sandbox の template の再ビルドは、mcpc を template に入れる（または mcpc の version を上げる）ときだけ必要です。
gateway 経路は template の managed settings が最初から許可しているため、再ビルドは要りません。

### mcpc 経路（既定）で使う

```bash
mise run apm:install                 # config/mcpc/mcp*.yml から mcpc 用 config を生成
mise run sandbox:build-template      # 初回・mcpc の version を上げたときだけ（template に mcpc を入れる）
mise run sandbox:mcpc notion metabase
sbx-agent claude --new               # config の mount と token は作成時に渡るため、既存の sandbox は作り直す
```

- `sandbox:add-mcp` による sbx への登録は使いません。gateway 経路から移ってきた場合、登録が残っていても
  `sbx-agent` が読み込まないので害はありません。不要なら消します（OAuth の token も消えるため、gateway 経路に
  戻すときは認可をやり直します）。

  ```bash
  sbx mcp ls
  sbx mcp rm <name>                  # 一覧の server ごとに
  rm -rf ~/.local/state/sbx-mcp      # sandbox:add-mcp の登録記録
  ```

### sbx gateway 経路（オプション）に切り替える

```bash
mise run sandbox:mcpc-stop            # mcpc の proxy を止める（任意）
mise run sandbox:add-mcp         # add: config/mcpc/mcp*.yml を host の sbx に登録（remote は初回だけ OAuth）
sbx-agent claude                     # sandbox を起動（起動時には何も load しない）
mise run sandbox:load-mcp            # load: 必要な server だけ起動中の sandbox に足す（fzf で選ぶ）
```

- 定義を変えたら `mise run sandbox:add-mcp` を再実行します（変わった server だけ登録し直す）。

### mcpc 経路に戻す

```bash
sbx-agent claude --new               # load 済みの server を外すため、sandbox を作り直す
mise run sandbox:mcpc notion metabase
```

起動済みの sandbox に load した server は、作り直すまで agent に見え続けます（`sbx-agent` は起動時に load しないので、
作り直した sandbox の gateway は空です）。

## devcontainer で使う

devcontainer では Claude Code の native MCP を managed settings で止めています（[`docs/devcontainer.md`](devcontainer.md#mcp)）。
mcpc は CLI なのでこの制限を受けず、mount した host 用 config から container 内で server を起動して使えます。
server は container 内で動くため、remote の OAuth は container 内で `mcpc login <url>` します。host の
credential（keychain・環境変数）は container に渡していません。`chrome-devtools` の `localhost:9222` は container
自身を指すため、host の Chrome には繋がりません。

## tool を検索して必要な schema だけ読む

```bash
mcpc                                   # 接続中の session
mcpc grep -E 'log|query'               # tool 名を検索
mcpc @context7 tools-get <tool-name>
mcpc @context7 tools-call <tool-name> key:=value
```

複雑な引数は JSON を標準入力から渡すと shell quoting の事故を避けられます。

```bash
jq -n --arg name 'react' '{libraryName: $name}' |
  mcpc --json @context7 tools-call resolve-library-id
```

## AI agent から使う

mcpc 自身が agent 向けの最新ガイドを出力します。agent の instructions に次の方針を追加すると、MCP tool を
常時登録せず Bash 経由で段階的に発見できます。

```text
MCP が必要なときは `mcpc help --skill` を確認する。
必要な server だけ `mcpc connect <config>:<server> @<session>` で接続する
（host は ~/.local/state/mcpc/apm-home/.copilot/mcp-config.json、sandbox 内では "$MCPC_SANDBOX_CONFIG"）。
`mcpc grep` → `tools-get` → `tools-call` の順に必要な tool だけを調べる。
作業後は `mcpc close @<session>` で session を閉じる。
```

## トラブルシューティング

- `mcpc connect` が失敗したら `mcpc @<session> logs`（`~/.mcpc/logs/bridge-@<session>.log`）を確認します。
- sandbox から繋がらない: host で `mcpc` を実行して `@sbx-<server>` が動いているか、`sbx policy log <sandbox-name>` で
  `localhost:<port>` がブロックされていないか、sandbox 内で `echo "$MCPC_SANDBOX_CONFIG"` が空でないか（空なら
  config 生成前に作った sandbox なので作り直す）を確認します。
- 401 になる: host の token と sandbox の `MCPC_PROXY_TOKEN` が違います。token を作り直した場合は sandbox を作り直します。
- remote の認証エラー: host で `mcpc login <url>` し直し、`mise run sandbox:mcpc <server>` で proxy を張り直します。

## 関連リンク

- [apify/mcpc](https://github.com/apify/mcpc)（[MCP proxy](https://github.com/apify/mcpc#mcp-proxy) / [AI sandboxes](https://github.com/apify/mcpc#ai-sandboxes)）
- [Docker Sandboxes の MCP gateway](https://docs.docker.com/ai/sandboxes/mcp-gateway/)
- [microsoft/apm](https://github.com/microsoft/apm)
