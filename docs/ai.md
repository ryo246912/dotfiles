# AI エージェント

## snippet を使わずに起動する

### ホスト

初回は `~/.claude` の設定を各アカウントへ共有する symlink を作ります。
devcontainer の initialize でも同じコマンドを実行するので、一度 devcontainer を起動していれば不要です。

```bash
claude-share-config
```

```bash
# account2 のアカウント
CLAUDE_CONFIG_DIR=~/.claude-account2 claude --dangerously-skip-permissions

# work3 のアカウント
CLAUDE_CONFIG_DIR=~/.claude-work3 claude --dangerously-skip-permissions
```

### devcontainer

`devcontainer exec` の `--` 以降がコンテナ内で実行されます。先に `dcup` で起動しておきます。
`~/.claude-account2` と `~/.claude-work3` は base template でコンテナへ mount しています。

```bash
# account2 のアカウントで Claude Code を起動
devcontainer exec --workspace-folder . --config ~/.config/devcontainer/devcontainer.json \
  -- env CLAUDE_CONFIG_DIR=/home/vscode/.claude-account2 claude --dangerously-skip-permissions

# work3 のアカウントで Claude Code を起動
devcontainer exec --workspace-folder . --config ~/.config/devcontainer/devcontainer.json \
  -- env CLAUDE_CONFIG_DIR=/home/vscode/.claude-work3 claude --dangerously-skip-permissions
```

multi-worktree の task root では `--config` を省略します（task root に生成された
`.devcontainer/devcontainer.json` が使われます）。

## セッションを分岐する（fork）

既存セッションの会話履歴をコピーして、**新しいセッション ID の別セッション**として続けます。
元のセッションの transcript はそのまま残るので、「A 案と B 案を両方試す」「調査の途中から別の方向に進める」
といった使い方ができます。

`/fork [name]` で、今開いている会話をこの時点で分岐します。

```text
/fork 別案を試す
```

- 実行すると**分岐先のセッションに切り替わります**（`You are now in the fork.`）。
  元の会話は分岐した時点の状態で残り、`claude -r <元の session-id>` で再開できます（実行時に表示されます）。
- `name` を省略すると、元のタイトルに `(Fork 1)` のような連番を付けた名前になります。
- 途中の時点から分岐したいときは、先に `/fork` してから分岐先で `/rewind`（`Esc` 2 回）で巻き戻します。
  元の会話を `/rewind` すると元側の履歴が巻き戻るので、順番に注意します。

> [!NOTE]
> 分岐しても**ファイルの作業ツリーは共有**です（`/fork` は worktree を作りません）。
> 両方のセッションで同じファイルを編集するなら、`multi-worktree` や `git worktree` で作業場所を分けてから起動します。
> 分けずに片方で編集すると、もう片方の Edit が `File has been modified since read ... Read it again` で
> 拒否されます（権限エラーではなく、読み直せば書ける）。

## 複数セッションを並走させる（agent view）

Claude Code には、1 つの画面から複数のセッションを起動・監視・切り替えできる
**agent view** があります（research preview）。空のプロンプトで `←` を押すと出てくる
セッション一覧がこれです。公式ドキュメントは [Agent view](https://code.claude.com/docs/en/agent-view)。

> [!NOTE]
> 「同じ claude プロセスの中で別セッションを開く」機能ではありません。
> 各セッションは **supervisor（バックグラウンドサービス）配下の別々の Claude Code プロセス**として動きます。
> 1 つの画面から操作できるだけで、プロセスや隔離環境が共有されるわけではありません。
> リソースの話は [sandbox ごとに起動する場合との比較](#sandbox-ごとに起動する場合との比較) を参照。

### 開く・閉じる

| 操作                                         | 方法                                                                           |
| -------------------------------------------- | ------------------------------------------------------------------------------ |
| agent view を開く                            | `claude agents`（`--cwd <dir>` でそのディレクトリ配下のセッションだけに絞る）  |
| 今の会話をバックグラウンドに回して一覧を開く | 空のプロンプトで `←`、または `/bg`（`/background`）                            |
| 今の会話をコピーして別セッションで並走させる | `/fork`（[セッションを分岐する](#セッションを分岐するfork) を参照）            |
| 一覧から抜ける                               | `Esc`（セッションは止まらない）                                                |
| `claude` 単体で agent view を開くようにする  | `/config defaultToAgentsView=true`                                             |
| `←` で一覧に飛ぶ挙動を止める                 | 設定 `leftArrowOpensAgents: false`                                             |
| agent view 自体を無効化                      | 設定 `disableAgentView: true`、または環境変数 `CLAUDE_CODE_DISABLE_AGENT_VIEW` |

`←` で一覧に移ると、そのセッションの行が選択された状態になります。`Esc` で会話に戻るか、
`Enter` で開き直せます。ツール実行中は 10 秒ほど待ってから切り替わり、権限プロンプトや
入力途中のテキストがあると切り替わらないことがあります。

### 一覧の操作

| キー                  | 動作                                                              |
| --------------------- | ----------------------------------------------------------------- |
| `↑` / `↓`             | 行の移動                                                          |
| `Enter` / `→`         | 選択したセッションにアタッチ                                      |
| `Space`               | peek パネル（中身をのぞく）の開閉                                 |
| `Alt+1`..`Alt+9`      | 表示中ディレクトリのセッション 1〜9 にアタッチ                    |
| `Ctrl+T`              | pin / unpin（pin したセッションはアイドルでもプロセスを止めない） |
| `Ctrl+R`              | 名前を変更                                                        |
| `Ctrl+S`              | 状態別 / ディレクトリ別のグルーピング切り替え                     |
| `Ctrl+F`              | 名前で検索                                                        |
| `Ctrl+X`              | 停止。2 秒以内にもう一度押すと削除                                |
| `Ctrl+G`              | dispatch するプロンプトを `$EDITOR` で編集                        |
| `Shift+↑` / `Shift+↓` | グループ内で並べ替え                                              |
| `?`                   | ショートカット一覧                                                |

アタッチ中は、空のプロンプトで `←`・`/exit`・`Ctrl+Z`（元いた場所に戻る）でデタッチします。
**デタッチしてもセッションは止まりません。** 止めるときは一覧で `Ctrl+X` か `/stop`。

キーは `~/.claude/keybindings.json` の `Agents` コンテキストで変更できます。

### 新しいセッションを起動する（dispatch）

一覧の入力欄にプロンプトを書いて `Enter` すると、1 プロンプト = 1 セッションで起動します。

| 入力                     | 効果                                                 |
| ------------------------ | ---------------------------------------------------- |
| `<prompt>`               | 新しいセッションを起動                               |
| `@<agent-name> <prompt>` | カスタム subagent をメインエージェントとして起動     |
| `/<command>`             | skill / command を最初のプロンプトとして起動         |
| `! <command>`            | シェルコマンドだけをバックグラウンドジョブとして実行 |
| `#<number>` / PR の URL  | その PR を担当している既存セッションを選択           |

シェルからも起動できます（`-p` / `--print` とは併用不可）。

```bash
claude --bg "flaky な SettingsChangeDetector のテストを調査して"
claude --bg --name flaky-test-fix "flaky なテストを調査して"
claude --agent code-reviewer --bg "PR 1234 のレビューコメントに対応して"
claude --resume <session-id> --bg "続きをやって"

# dispatch 時の既定を指定して agent view を開く
claude agents --permission-mode plan --model opus --effort high
```

#### 権限モード

- `←` / `/bg` でバックグラウンドに回したセッションは、今の権限モードをそのまま引き継ぎます。
- 一覧から dispatch したセッションは、対象ディレクトリの `permissions.defaultMode` が使われます。
  ただし `auto` / `bypassPermissions` はユーザー設定（`~/.claude/settings.json`）・managed settings・
  `--settings` で指定したときだけ有効で、プロジェクト設定からは選べません。
- `claude agents --dangerously-skip-permissions` のように、開くときのフラグで既定を渡すこともできます。

### ファイル編集の隔離（worktree）

一覧や `--bg` から dispatch したセッションは、ファイルを編集する前に
`.claude/worktrees/` 配下に**専用の git worktree を作ってそこへ移動**します。
並列セッションが同じファイルを書き合わないための仕組みです。次の場合は worktree を作りません。

- `←` / `/bg` で、すでに開いていたセッションをバックグラウンドに回したとき
- すでに linked worktree の中にいるとき（`multi-worktree` の worktree はこれに当たる）
- git リポジトリではなく、`WorktreeCreate` hook も無いとき

**このリポジトリでは無効化しています**（`claude/settings.json`）。dispatch したセッションも
今の作業ディレクトリをそのまま編集するので、並列で同じファイルを触らないよう役割を分けるか、
`multi-worktree` で worktree を分けてから起動します。

```json
{
  "worktree": {
    "bgIsolation": "none"
  }
}
```

有効にしている場合、一覧から削除すると **Claude が作った worktree も未コミットの変更ごと消えます。** 残したいものは
先にコミット・push しておきます（未 push のコミットがある worktree は削除がブロックされます）。

### スクリプトから操作する

```bash
claude agents --json          # 稼働中のセッション（--all で完了済みも）
claude attach <id|name>
claude logs <id|name>
claude stop <id>
claude respawn <id>           # 再起動（--all で全部）
claude rm <id>                # 一覧から削除（transcript は claude --resume で残る）

claude daemon status          # supervisor の状態・ワーカー数
claude daemon logs            # ~/.claude/daemon.log を追う
claude daemon stop --any --keep-workers   # セッションを残して supervisor だけ再起動
```

状態は `~/.claude/jobs/<id>/state.json` を直接読まず、`claude agents --json` の `state`
（`working` / `blocked` / `done` / `failed` / `stopped`）を使います。

#### 複数アカウントとの関係

`CLAUDE_CONFIG_DIR` を設定していると、supervisor はその設定ディレクトリを使う**別インスタンス**として
動きます。[ホスト](#ホスト) の account2 / work3 のように `CLAUDE_CONFIG_DIR` を切り替えて
起動している場合、agent view の一覧もアカウントごとに分かれます。

### プロセスの仕組み

- 最初にセッションをバックグラウンドに回すか `claude agents` を開いたときに、
  **supervisor** が起動します。端末や agent view を閉じてもセッションが生き残るのはこのためです。
- **各セッションは supervisor 配下の独立した Claude Code プロセスです。**
- 作業中・権限待ち・アタッチ中のセッションはプロセスが動き続けます。
- 完了または入力待ちで、**約 1 時間アタッチされていないセッションはプロセスが止められます。**
  会話はディスクに残り、次にアタッチ・返信したときに再開します（初回応答が少し遅くなる）。
  止めたくなければ `Ctrl+T` で pin します。
- 異常終了したプロセスは supervisor が再起動します。マシンをシャットダウンすると止まります。

| パス                           | 中身                                                        |
| ------------------------------ | ----------------------------------------------------------- |
| `~/.claude/daemon.log`         | supervisor のログ                                           |
| `~/.claude/daemon/roster.json` | 稼働中セッション（再接続用）                                |
| `~/.claude/jobs/<id>/`         | セッションごとの状態。`tmp/` はスクラッチ（削除時に消える） |

### sandbox ごとに起動する場合との比較

このリポジトリでは `multi-worktree dev` で **セッションごとに sbx sandbox（microVM）** を作っています
（[`docs/docker-sandboxes.md`](docker-sandboxes.md)）。agent view に寄せるとリソース的に得か、の整理です。

#### 結論

- **Claude Code のプロセス自体のコストはほぼ変わりません。** agent view でもセッションごとに
  別プロセスなので、「1 プロセスに相乗りして軽くなる」ことはありません。
- **差が出るのは sandbox（microVM）の数です。** sbx は sandbox ごとに VM・専用 kernel・
  専用 docker daemon・image store（template 数 GB）を持つため、並列数 N に比例して重くなります。
  agent view でまとめれば、この VM 側の N 倍が消えます。
- ただし **ホストで `claude agents` を使うと sandbox の隔離（ネットワーク制御・secret 注入・
  FS の露出制限）が丸ごと無くなります。** `--dangerously-skip-permissions` 前提の運用では
  ここが一番大きな差なので、単純に置き換えるのはおすすめしません。

| 観点                    | セッションごとに sandbox      | ホストで agent view                | 1 つの sandbox の中で agent view      |
| ----------------------- | ----------------------------- | ---------------------------------- | ------------------------------------- |
| Claude Code プロセス    | N 個                          | N 個 + supervisor                  | N 個 + supervisor                     |
| VM / docker daemon      | N 個                          | 0                                  | 1 個                                  |
| ディスク（template 等） | N 個分                        | 0                                  | 1 個分                                |
| アイドル時の回収        | 無し（`sbx stop` を手で打つ） | 約 1 時間でプロセス停止            | プロセスは停止、VM は残る             |
| 隔離                    | セッション間も VM で分離      | 無し（Claude Code の権限設定だけ） | ホストとは分離、セッション間は同じ VM |
| ファイル衝突の回避      | `multi-worktree` の worktree  | 無し（`bgIsolation: none`）        | 無し（役割を分ける）                  |

#### 使い分けの指針

- **安全性を優先する重い実装タスク**: これまで通りセッションごとに sandbox。
  並列させるときは `--cpus` / `--memory` を絞る。
- **同じタスク（同じ sandbox）の中で調査・レビューを並走させたい**: sandbox の中で
  `←` / `/bg` / `claude agents` を使う。VM は 1 つのまま、Claude のセッションだけ増やせます。
  sandbox から見えるのは `sbx-agent` が渡した workspace（task root・agent の設定ディレクトリ・
  git 設定などの追加 mount。[一覧](docker-sandboxes.md#sbx-agent-ラッパー)）だけなので、
  ホストとの隔離は sandbox 1 つのときと変わらず、増えるのはプロセス分のメモリだけです。ただし同じ VM 内のセッション同士は分離されないので、
  同じファイルを書き換える作業は並走させず、2 つ目以降は調査・レビューなど読むだけの役割にします。
  sandbox の中からは `multi-worktree` を実行できず（設定ファイルが無い）、ホストで新しく作った
  worktree も起動済みの sandbox には見えないので、編集を並列にしたいときは
  ホストで `multi-worktree` の別タスクとして別の sandbox を立てます。
- **隔離が要らない軽い作業**（ドキュメント調査・質問など）: ホストで `claude agents` から dispatch。
  VM を立てるより圧倒的に軽量です。

> [!NOTE]
> sandbox の中で agent view を使う構成は、この環境ではまだ動作確認していません。
> 使う場合、supervisor は sandbox の中で動きます。
> `sbx stop` すると sandbox 内のセッションもすべて止まり、ホストの `claude agents` からは見えません。

### agent view の注意点

- バックグラウンドセッションも通常どおり使用量を消費します。10 並列なら 10 倍の速さで枠を使います。
- セッションは別プロセスなので、増やしすぎるとメモリが枯渇します（`possibly low memory` で失敗する）。
- dispatch したセッションはコード変更をコミット・push するよう指示されています
  （`main` / `master` への push・force-push・merge はしない）。
- `claude agents` がセッション一覧ではなく subagent の一覧を出す場合は、agent view が使えない古い版です。`claude update` で更新します。

参考: [Manage agents with agent view](https://code.claude.com/docs/en/agent-view) / [Run agents in parallel](https://code.claude.com/docs/en/agents)

## effort（推論の深さ）の変え方

effort は、1 回の応答でどれだけ深く考えるか（thinking にどれだけトークンを使うか）の設定です。
上げるほど難しい問題に強くなり、出力トークン（＝rate limit の消費）と応答時間が増えます。
今の値はステータスラインのモデル名の右に表示されます（[表示の読み方](#表示の読み方)）。

### レベル

| レベル   | 使いどころ                                                                               |
| -------- | ---------------------------------------------------------------------------------------- |
| `low`    | 結果をすぐ自分で見る軽いやりとり（ブレスト・小さなリネーム）                             |
| `medium` | 範囲がはっきりした日常の作業。Opus 5.5・Sonnet 5.5・Haiku 5.5 の既定                     |
| `high`   | 検証が大事・エッジケースがありそうな作業（バグ修正など）。上記以外の対応モデルの既定     |
| `xhigh`  | さらに深く考える。トークン消費も増える                                                   |
| `max`    | 放っておいて解かせたい難問。考えすぎて効率が落ちることもある。**そのセッション限り**有効 |

- Opus 5.5 / Sonnet 5.5 / Haiku 5.5 / Fable 5.1 などは 5 段階すべて、Opus 4.6 / Sonnet 4.6 は `xhigh` 無しの 4 段階。
  非対応のレベルを指定すると、それ以下で一番高いレベルで動きます（Opus 4.6 の `xhigh` → `high`）。
- effort 非対応のモデル（Haiku 4.5 など）では設定は無視され、ステータスラインにも表示されません。

### 変え方

| 方法                                        | 例                                    | 範囲                                                                     |
| ------------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------ |
| `/effort <level>`                           | `/effort high`                        | そのモデルの既定として保存。Claude の作業中でも打てる                    |
| `/effort`（引数なし）                       | スライダーで `←` / `→`                | `Enter` で既定として保存、`s` でこのセッションだけ                       |
| `/effort auto`                              |                                       | 保存したレベルを消してモデルの既定に戻す                                 |
| `/model` のピッカー                         | モデルを選びつつ `←` / `→`            | `/effort` のスライダーと同じ                                             |
| `--effort` フラグ                           | `claude --effort xhigh`               | 起動したセッションだけ                                                   |
| `CLAUDE_CODE_EFFORT_LEVEL` 環境変数         | `CLAUDE_CODE_EFFORT_LEVEL=low claude` | その環境から起動したセッション。`max` もここなら保存される               |
| settings の `effortLevel` / `modelSettings` | `"effortLevel": "high"`               | `modelSettings` はモデルごと、`effortLevel` はそれ以外の既定。`max` 不可 |
| skill / subagent の frontmatter の `effort` | `effort: low`                         | その skill / subagent が動いている間だけ（環境変数には負ける）           |
| Remote Control の effort コントロール       | スマホ・ブラウザから選ぶ              | そのセッションだけ                                                       |

優先順位は「環境変数・`--effort`・セッション中の `/effort`」→「保存したモデルごとの値・`effortLevel`」→
「モデルの既定」です。1 ターンだけ深く考えさせたいなら、effort を変えずにプロンプトへ `ultrathink`
を入れます（API に送る effort は変わらない。「think hard」などはキーワードとして扱われません）。

> [!NOTE]
> `/effort <level>` は既定として**保存**されます。このリポジトリでは `~/.claude/settings.json` が
> `claude/settings.json` への symlink なので、保存すると `claude/settings.json` に `modelSettings` の差分が出ます。
> 一時的に変えたいだけなら `/effort` のスライダーで `s`（このセッションだけ）を使うか、`--effort` で起動します。
> また Opus 5.5 は、ユーザー設定の最上位 `effortLevel` を無視します（プロジェクト設定などの `effortLevel` は効く）。

- `/effort ultracode`（`--effort ultracode`）は effort レベルではなく、動的な workflow を組み立てるモードの on/off です。
  `--effort ultracode` は `xhigh` で始めて ultracode を on にします。
- cache への影響は [モデルと effort の切り替え方](#モデルと-effort-の切り替え方) を参照
  （Opus 5.5・Sonnet 5.5・Haiku 5.5・Fable 5.1 では `/effort` で cache は壊れない）。

参考: [Model configuration — Adjust effort level](https://code.claude.com/docs/en/model-config#adjust-effort-level)

## ステータスライン（prompt cache・rate limit・コンテキスト）

Claude Code はメッセージを送るたびに会話全体をモデルへ再送信します。prompt cache が
効いている（warm）間は前回までの処理を再利用できるので、返信が速く、使用制限への影響も
小さくなります。cache は TTL で期限切れ（cold）になり、その後の最初のメッセージは
会話全体を最初から処理し直します。ステータスラインには cache の残り時間を表示し、
cold になったら次のメッセージで再キャッシュされるトークン数を表示します。
あわせて、git branch・モデルと effort・コンテキストの残り・session id・rate limit（5h / weekly）の残りを表示します。
subagent が動いているときは、agent panel の各行にも model と effort を表示します（[subagent の行](#subagent-の行)）。

`claude/statusline.sh`（`~/.claude/statusline.sh` に配置）が描画します。
`claude/settings.json` の `statusLine.refreshInterval: 30` で、カウントダウンを
30 秒ごとに更新します。Claude Code v2.1.251 以降と `jq` が必要です。
`claude/` は symlink-each で `~/.claude` へ配置されます。初回は `mise bootstrap dotfiles apply`
で symlink を作成します。以降、既存ファイルの変更はそのまま反映されますが、`claude/` に
新しく追加したファイルは再度 apply するまで `~/.claude` に現れません。

### 表示の読み方

1 行目にアカウント・branch・モデル、2 行目にコンテキスト・session id・rate limit・cache を表示します。

```text
 account2  foo@example.com · main · Opus 5.5 ▰▰▰▰▱ xhigh
ctx ████░░ 62% left 76k/200k · 6f1d2c3a-8b4e-4f5a-9c7d-2e1b0a9f8c7d · 5h ████░░ 58% left reset 2h9m ✓ · week ██████ 84% left reset 3d21h ✓ · cache ● 1h ████░░ 38m left · hit 91% · misses 0
```

```text
 work3  bar@example.com · main · Opus 5.5 ▰▰▰▰▱ xhigh
ctx – waiting · 6f1d2c3a-8b4e-4f5a-9c7d-2e1b0a9f8c7d · 5h █░░░░░ 12% left reset 2h9m ⚠ empty 23m · week ██████ 84% left reset 3d21h ✓ · cache ○ cold · next message re-caches 82k tokens · last miss: ttl_expired_5m
```

| 表示                                | 意味                                                                                                                                                                                               |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `account2`（背景色）                | ログイン中のアカウント。config dir 名から決める（`~/.claude` → `account1`、`~/.claude-<name>` → `<name>`）。背景色は account1 青・account2 紫・work3 黄・その他 灰                                 |
| `foo@example.com`（太字）           | ログイン中のメールアドレス（global config の `oauthAccount.emailAddress`。`CLAUDE_CONFIG_DIR` 指定時は `<dir>/.claude.json`、未指定時は `~/.claude.json`）。API キー利用などで無い場合は表示しない |
| `main`（シアン）                    | 作業ディレクトリの git branch。detached HEAD のときは短縮 SHA、git 管理外では表示しない                                                                                                            |
| `Opus 5.5`（紫）                    | モデル名（`model.display_name`）                                                                                                                                                                   |
| `⚡`（黄）                          | fast mode が有効（`fast_mode`）                                                                                                                                                                    |
| `▰▰▰▰▱ xhigh`                       | reasoning effort（`effort.level`）。ゲージは low 1〜max 5 マス、色は low 灰・medium 緑・high シアン・xhigh 黄・max 赤。`/effort` の変更は次の更新で反映。effort 非対応モデルでは表示しない         |
| `ctx ████░░ 62% left 76k/200k`      | コンテキストウィンドウの残り割合と使用量/上限（`context_window.*`）。残り 20% 未満で黄、10% 未満で赤。最初の応答前・`/compact` 直後は `ctx – waiting`                                              |
| `6f1d2c3a-…`（灰）                  | セッション ID（`session_id`）。`claude --resume <id>` で再開するときに使う。表示は省略せず全桁                                                                                                     |
| `5h` / `week`（青）                 | rate limit の 5 時間枠・週枠の残り割合（`rate_limits.five_hour` / `seven_day`）。残り 20% 未満で黄、5% 未満で赤。Pro/Max のみ                                                                      |
| `reset 2h9m`                        | rate limit の枠がリセットされるまでの時間（`rate_limits.*.resets_at` から計算）                                                                                                                    |
| `✓`                                 | ここまでの消費ペース（使用率 ÷ 経過時間）が続いても、リセットまで枠が持つ                                                                                                                          |
| `⚠ empty 23m`（黄/赤）              | 今のペースだとリセット前に枠を使い切る。表示はそれまでの時間。リセットまでの半分も持たないときは赤。枠の経過が 10% 未満の間は予測しない                                                            |
| `●`（緑）                           | cache が warm。次のメッセージは cache を再利用できる                                                                                                                                               |
| `●`（黄）                           | warm だが、残り時間が TTL の 20% 未満。続けて聞きたいことがあれば今のうちに送る                                                                                                                    |
| `○ cold`（赤）                      | cache が warm でない（TTL 切れ、または直近の応答に cache token が無い）。次のメッセージで会話全体を処理し直す                                                                                      |
| `– waiting`（灰）                   | まだ `prompt_cache` が届いていない（セッションの最初の応答前、または Claude Code が v2.1.251 未満）                                                                                                |
| `– not observed`（灰）              | このセッションでまだ cache token が報告されていない（`prompt_cache.caching_observed` が `false`。caching が無効、または provider/gateway が報告しない）                                            |
| `1h` / `5m`                         | 現在の cache の TTL（`prompt_cache.ttl`）                                                                                                                                                          |
| `████░░`                            | TTL に対する残り時間の割合（6 マス）                                                                                                                                                               |
| `38m left`                          | cold になるまでの残り時間（`prompt_cache.expires_at` から計算。1 分未満は秒）                                                                                                                      |
| `hit 91%`                           | このセッションの入力トークンのうち cache から読めた割合（`prompt_cache.hit_ratio`）                                                                                                                |
| `misses 0`                          | cache にあるはずの内容を処理し直したリクエスト数（`prompt_cache.misses`）。compaction などによる想定内の再構築は含まない                                                                           |
| `next message re-caches 82k tokens` | cold のとき、次のメッセージで再キャッシュされるトークン数（`prompt_cache.recache_tokens_if_cold`、k 単位で丸め）                                                                                   |
| `last miss: ...`                    | 直近の miss の推定原因（`prompt_cache.last_miss_cause.causes`）。原因が分かったときだけ表示                                                                                                        |

`prompt_cache` は main conversation の最初の API 応答後に入力へ現れるため、それまでは
灰色で `cache – waiting` を表示します（Claude Code が v2.1.251 未満の場合もこの表示のままです）。使っている Claude Code のバージョンに無いフィールドは表示を省きます。
subagent のリクエストはこの統計に含まれません。

`rate_limits` も最初の API 応答まで届かないため、受け取った値を config dir ごとに
`${CLAUDE_CONFIG_DIR:-~/.claude}/statusline-rate-limits.json` へ保存し、prompt を送る前は
リセット前の保存値を表示します。保存値は前回の応答時点のものなので、その後に他のセッションで
使った分は最初の応答まで反映されません。

メールアドレスも、数 MB になりうる global config を毎回 parse しないよう
`${CLAUDE_CONFIG_DIR:-~/.claude}/statusline-account-email` へ保存し、global config が
更新されるまでは保存値を表示します。

### subagent の行

agent panel（プロンプト下の subagent 一覧）の各行は、`claude/subagent-statusline.sh`
（`settings.json` の `subagentStatusLine`）が描画します。既定の行に、subagent の model と effort を足しています。

```text
reviewer · Reading files · haiku-5-5 low · 12k tokens
Explore · Find callers of login · 800 tokens
```

- effort は subagent 定義の frontmatter（`effort: low` など）か、呼び出し時に指定された値です。
  未指定のときは表示しません（セッションの effort を引き継ぐ）。数値（トークン予算）のときは `8k tok` のように表示します。
- model は解決されるまで表示しません。色は effort はメインのステータスラインと同じ、model は紫です。
- `claude/` に新しく追加したファイルなので、初回は `mise bootstrap dotfiles apply` で `~/.claude` へ symlink を作成します。

参考: [Customize your status line — Subagent status lines](https://code.claude.com/docs/en/statusline#subagent-status-lines)

### cache を長持ちさせるための注意

- 既定の cache TTL は、サブスクリプションのプラン内利用では main conversation が 1 時間、
  subagent と workflow が 5 分です。API キー利用時や、使用制限を超えて使用クレジットに
  移ったときは、main conversation も 5 分になります。TTL は main conversation なら
  `promptCacheTtl`（または `CLAUDE_CODE_PROMPT_CACHE_TTL`）、subagent などは
  `subagentPromptCacheTtl`（または `CLAUDE_CODE_SUBAGENT_PROMPT_CACHE_TTL`）で `5m` / `1h`
  に変更できます（v2.1.242 以降）。
- セッション中にモデルを切り替えると cache はすべて作り直しになります。`opusplan` では
  plan mode への出入りも切り替えとして扱われます。
- プロジェクトルートとユーザーレベルの `CLAUDE.md` はセッション開始時に読み込まれます。
  セッション中に編集しても cache は壊れませんが、編集内容は `/clear`・`/compact`・再起動の
  いずれかまで反映されません。サブディレクトリの nested `CLAUDE.md` や `paths:` 付きの
  rule は必要になった時点で読み込まれるため、読み込まれる前の編集はそのまま反映されます。
- やり直したいときは `/rewind` で戻ると既存の cache を再利用できます。`/compact` は
  新しい cache を作ります。

### cache を意識した使い方

基本は「cache が warm のうちに続けて指示を送る」方が得です。ただし、cache を保つためだけに
メッセージを送るのは、多くの場合は得になりません。

#### なぜ warm のうちに送ると得か

以下の「〜倍」は、cache を使わない通常の入力トークンの料金を 1 としたときの比率です
（API 料金での目安）。

| 入力の種類                   | 料金の比率                                  |
| ---------------------------- | ------------------------------------------- |
| 通常の入力（cache なし）     | 1 倍                                        |
| cache から読む（hit）        | 約 0.1 倍（9 割引）                         |
| cache に書き込む（作り直し） | 5 分 TTL で約 1.25 倍、1 時間 TTL で約 2 倍 |

- warm のうちは、会話の大部分を約 0.1 倍で読めます。
- cold になると、会話全体をもう一度 cache に書き込みます。通常の入力より高い 1.25 倍 / 2 倍が
  会話全体にかかります。
- API キーではこの比率がそのまま請求額に効きます。サブスクリプションでは直接の請求はありませんが、
  同じ比率で使用制限の減り方に効きます。返信も速くなります。
- cache に当たるたびに TTL はリセットされます。続けてやり取りしている間はずっと warm のままです。

#### hit 率と料金の関係

hit 率（ステータスラインの `hit 91%`）が高いほど入力の料金は下がります。ただし反比例ではなく、
ほぼ直線的に下がります。書き込みの割増しを除いた入力料金の目安は次のとおりです。

```text
入力料金 ≈ (1 − hit 率) × 1 + hit 率 × 0.1
```

式の hit 率は 0〜1 の割合です（`hit 91%` なら 0.91）。

| hit 率 | 入力料金（cache なしとの比） |
| ------ | ---------------------------- |
| 0%     | 1.0 倍                       |
| 50%    | 約 0.55 倍                   |
| 90%    | 約 0.19 倍                   |

- 下がるのは入力の料金だけです。出力トークンの料金は cache の有無で変わりません。
- cold になるたびに会話全体を割増し（1.25 倍 / 2 倍）で書き直すので、実際の損は hit 率の
  数字から見えるより大きくなります。

#### 実際の使い方

1. 同じ作業の続きなら、間を空けずに送ります。黄色（残り 20% 未満）になっていて、
   まだ聞きたいことがあるなら、今のうちに聞きます。
2. cache を保つためだけの「つなぎ」の送信は基本しません。その送信自体にも cache 読み込みと
   出力の分のコストがかかります。元を取れるのは、TTL 内に確実に作業を再開し、つなぎの
   送信のコスト（会話全体の cache 読み込み ≈ 0.1 倍＋つなぎメッセージ自体の入力＋出力）が cold 後の再書き込み
   （1.25 倍 / 2 倍）より小さくなる場合だけです。会話の長さ・出力量・モデルによって
   変わるので、固定の目安はありません。
3. cold になったら、送る前に続けるかどうかを考えます。ステータスラインの
   `next message re-caches 82k tokens` がその再送のコストです。
   - 前の文脈がもう要らないなら、`/clear` で新しく始めた方が安いです。
   - 文脈は要るけれど長すぎるなら、`/compact` で縮める手もあります。ただし cold 時の
     `/compact` は要約を作るために会話全体を cache なしで処理し直すので、`/compact`
     としては最もコストが高くなります。縮めた文脈でこの後も何度もやり取りする場合に
     元が取れます。`/compact` はなるべく warm のうち（作業の区切り）に実行します。
4. 話題が変わるときは、cold かどうかに関係なく `/clear` します。関係のない長い履歴を
   毎回送り続けるのは、cache が効いていても無駄です。
5. cache を壊す操作に注意します。モデルの切り替えや、`opusplan` での plan mode の出入りは、
   warm でも cache を作り直しにします。

まとめると、作業はまとまった時間で一気に進め、区切りでは warm のうちに `/compact` し、
休憩明けで cold になっていたら、続けるか `/clear` するかを選ぶのが一番得な使い方です。

参考: [Customize your status line — Prompt cache fields](https://code.claude.com/docs/en/statusline#prompt-cache-fields) /
[How Claude Code uses prompt caching](https://code.claude.com/docs/en/prompt-caching)

## トークン使用量を抑える

別タスクで `/clear` するだけでは、**同じタスクの長いラリー**で消費が膨らむのを防げません。
Claude Code はメッセージのたびに会話全体を送るので、1 ターンのコストは「その時点の会話の長さ」に
比例します。cache が warm でも 0.1 倍で読み直すだけなので、会話が長くなるほど 1 ターンが重くなります。
ツールを 1 回呼ぶたびにも同じ量を読み直すため、1 往復のラリーでも内部では何回分もかかります。

### 長いラリーで使いすぎる原因

Opus 5.5・Sonnet 5.5・Haiku 5.5 などは**既定で 1M コンテキスト**で動き、auto-compact は
**約 967K トークンまで発動しません**。つまり何もしなければ、同じタスクを続ける限り会話は
数十万トークンまで膨らみ続け、その全体を毎ターン（毎ツール呼び出し）読み直します。

| 会話の長さ | 1 ターンで読む量（cache hit 時の課金換算） |
| ---------- | ------------------------------------------ |
| 50K        | 50K × 0.1 = 5K 相当                        |
| 200K       | 200K × 0.1 = 20K 相当                      |
| 600K       | 600K × 0.1 = 60K 相当                      |

200K で止めるだけで、600K まで伸びた場合に比べて 1 ターンあたり約 1/3 になります。

### このリポジトリの設定

`claude/settings.json` に次を入れています（全アカウント共通。`~/.claude-*` は
`settings.json` を symlink で共有）。

```json
{
  "autoCompactWindow": 200000
}
```

- 会話が 200K に達したら auto-compact します（指定できる範囲は 100K〜1M）。
- 調査結果を大量に抱えたまま進めたいタスクだけ、`claude --autocompact 500k` で起動して
  その起動中だけ広げます。セッション中の `/autocompact 500k` でも変えられますが、モデルごとの値として
  ユーザー設定の `modelSettings` に書き込まれ（＝このリポジトリの `claude/settings.json` が変わる）、
  上の値より優先され続けるので、使ったら `/autocompact 200k` で戻すか差分を捨てます。
- コミュニティ記事でよく出てくる `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` は公式ドキュメントに無く、
  効かないという報告が多いので使いません。

> [!NOTE]
> 閾値を下げるほど compact の回数は増え、要約で細部が落ちます。compact は会話全体を読む
> 1 回分のリクエストなので、200K より大きく下げても得にはなりにくいです。
> 細部が要る作業は、ファイル（plan・メモ）に書かせておくと compact 後も読み直せます。

### compact を自分で打つ

auto-compact は作業の途中で発動します。区切りがついた時点で、cache が warm なうちに
自分で `/compact` する方が安く、要約の質も上がります。

```text
/compact 決定事項・変更したファイル・残りの TODO を残して。試行錯誤の経緯は捨ててよい
```

- 失敗した方向に進んだときは `/compact` ではなく `/rewind`（`Esc` 2 回）で戻ります。
  既存の cache をそのまま使えます。
- 話の途中で状況を確認したいだけなら `/recap`。会話を書き換えないので cache を壊しません。
- 長い会話を cold の状態で再開すると、Pro / Max では「要約から再開」を提案されます。
  文脈を細かく覚えていなくてよければ要約を選びます。

### モデルと effort の切り替え方

| 操作               | cache への影響（サブスクリプション / API キー）                                           |
| ------------------ | ----------------------------------------------------------------------------------------- |
| `/effort` の変更   | Opus 5.5・Sonnet 5.5・Haiku 5.5・Fable 5.1 では**壊れない**。それ以外のモデルでは作り直し |
| `/model` の変更    | **作り直し**（会話全体を書き込み直す）                                                    |
| `opusplan`         | plan mode の出入りのたびにモデルが変わるので、そのたびに作り直し                          |
| fast mode を入れる | 最初の 1 回だけ作り直し（以降の on / off は維持）                                         |
| 権限モードの変更   | 壊れない（`opusplan` を除く）                                                             |

使い分けは次のとおりです。

1. **effort はラリー中に気軽に変えてよい。** 方針を決める・難しいバグを追うときは `/effort high`
   以上、方針が決まった後の機械的な修正や確認は `/effort low`〜`medium` に下げます。
   thinking は出力トークンとして数えられるので、効くのは出力側です。1 ターンだけ深く考えさせたいなら、
   effort を変えずにプロンプトへ `ultrathink` を入れます。
2. **モデルはセッションの最初に決めて、途中で変えない。** 途中で変えると会話全体を割増しで
   書き直すので、長いラリーの後半ほど損です。変えたいときは `/compact` か `/clear` の直後
   （どのみち cache を作り直すタイミング）に変えます。
3. **重い調査・ログ読みは subagent に出す。** 大量のファイルやログは subagent の文脈に閉じて、
   メインの会話には要約だけが戻ります。メインの会話が膨らまないことが一番効きます。
   subagent 自体のトークンを減らすなら、定義の `model: haiku` か
   `CLAUDE_CODE_SUBAGENT_MODEL` で小さいモデルにします（このリポジトリでは未設定）。

### その他の習慣

- **指示を具体的にする。** 「直して」より「`auth.ts` の `login` に入力チェックを足して」の方が、
  ファイルの探索（＝読み込み）が少なく済みます。
- **出力の大きいコマンドは絞る。** テストやログはそのまま読ませず `| tail` / `grep` で絞ります。
  このリポジトリでは [rtk](rtk.md) の PreToolUse hook が Bash の出力を圧縮しています。
- **`CLAUDE.md` は短く保つ。** 毎回の先頭に載るので、特定作業の手順は skill に移します
  （skill は呼ばれたときだけ読まれる）。
- **使っていない MCP は切る。** `/mcp` で無効化し、`gh` などの CLI で済むものは CLI を使います。
- **何に使ったかを見る。** `/usage` で、使用量のうち skill・subagent・MCP が占める割合と、
  long context や cache miss が 10% 以上を占めているかの警告が見られます。`/context` で
  今の会話の中身の内訳が見られます。セッションをまたいだ分析は [codeburn](codeburn.md) /
  [AgentsView](agentsview.md) / [cclens](#cclens-で無駄を診断する)。

参考: [Manage costs effectively](https://code.claude.com/docs/en/costs) /
[Model configuration — Context window and auto-compaction](https://code.claude.com/docs/en/model-config#context-window-and-auto-compaction) /
[How Claude Code uses prompt caching](https://code.claude.com/docs/en/prompt-caching)

## スキル

スキルのコンテキスト管理、配布、各スキルの使い方は [AIスキル](ai-skill.md) にまとめています。

## cclens で無駄を診断する

[cclens](https://github.com/lambdalisue/cclens) は、Claude Code のセッション transcript と現在の設定を
読み取って SQLite に蓄積し、時間・トークン・手間がどこで無駄になっているかを報告する CLI です。
解析・レポートはすべてローカルで完結し、外部には何も送信しません。
ただし `cclens optimize` は、指摘事項を `claude`（Claude Code）のセッションに渡します。

導入は `config/mise/config.toml` の `"github:lambdalisue/cclens"` で行っています（GitHub Release のバイナリ）。
`mise install` で `cclens` が使えるようになります。

### 使い方

まず `doctor` で全体を確認します。

```bash
cclens doctor                    # 1画面の健康診断（global / project 別の指摘）
cclens doctor --scope global     # ~/.claude 側の設定だけを対象にする
cclens doctor --scope project    # プロジェクト側の設定だけを対象にする（全プロジェクトが対象）
cclens doctor --scope project:<slug>  # 特定の1プロジェクトだけを対象にする
```

`doctor` の結果を見て、必要な観点のレポートを開きます。

| コマンド                  | 内容                                                           |
| ------------------------- | -------------------------------------------------------------- |
| `cclens waste`            | 無駄になっているトークン・手間                                 |
| `cclens inventory`        | 設定（skill / agent / MCP など）の棚卸し                       |
| `cclens overhead`         | 毎回の先頭に載る固定コスト                                     |
| `cclens usage --by month` | 期間別の使用量                                                 |
| `cclens failures`         | 失敗したツール呼び出し                                         |
| `cclens prompts`          | プロンプトの傾向                                               |
| `cclens stuck`            | 行き詰まったセッション                                         |
| `cclens sql '<query>'`    | ストアに対する読み取り専用 SQL（stdin からも可）               |
| `cclens optimize`         | 指摘事項を対話的な `claude` セッションに渡して改善案を作らせる |

共通オプション:

- `--scope global | project | project:<slug>`: 対象にする設定のレイヤーを絞る
  （`doctor` / `failures` / `waste` / `inventory` / `optimize`）
- `--format markdown | json`: markdown は PR への貼り付け用、json は機械処理用。
  対応形式はコマンドごとに異なる（例: `usage` は `table | markdown`、`doctor` は `table | json`）ので、
  `cclens <command> --help` で確認する
- `--db <path>`: DB ファイルを指定する
- `--frozen`: ストアを更新せず、今ある内容をそのまま読む

読み取り系のコマンドは実行時に `cclens analyze` を自動で走らせてストアを更新します。
ただし `sql` は自動で更新しないため、最新の内容を対象にしたいときは先に `doctor` か `analyze` を実行します。

### 分析の進め方

`doctor` の出力は 4 つのブロックに分かれます。上から順に、次のように掘り下げます。

| ブロック             | 読み方                                                                                                                                            | 掘り下げるコマンド                                  |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| WHAT TO FIX FIRST    | 優先度順の失敗。複数プロジェクトで起きているものは `~/.claude`（グローバル設定）、1 プロジェクトに偏るものはそのプロジェクトの `CLAUDE.md` で直す | `cclens failures --scope global` / `project:<slug>` |
| COST                 | 毎セッションの固定コスト。自分の設定ぶんは削れるが、Claude Code 本体（system prompt・組み込みツール・MCP スキーマ）は削れない                     | `cclens overhead` / `cclens usage`                  |
| CONFIG WORTH PRUNING | 一度も使われていない surface。「解析対象のセッションで使っていない」だけなので、消す前に中身と用途を確認する                                      | `cclens waste --scope global`                       |
| LOOKS HEALTHY        | 問題なしの観点。steering / corrections の割合が低ければ、自律的に進められている                                                                   | `cclens prompts`                                    |

#### 失敗（`failures`）の分析

1. `cclens failures --scope global` でカテゴリ別の件数を見る。
2. 件数の多いカテゴリは、`cclens sql` で生のエラー文を集計して中身を確認する。
   カテゴリ名だけでは原因が分からないため（特に `command-failed` / `other` は未分類）。
3. 原因に応じて、ルール・hook・環境のどこで直すかを決める。

```bash
cclens analyze   # sql は自動更新しないので、先にストアを最新にする
cclens sql "SELECT category, tool, COUNT(*) n FROM tool_errors GROUP BY 1,2 ORDER BY n DESC"
cclens sql "SELECT substr(excerpt,1,110) e, COUNT(*) n FROM tool_errors WHERE category='blocked-by-hook' GROUP BY 1 ORDER BY n DESC LIMIT 10"
```

`tool_errors` ビューのカラムは `category` / `excerpt` / `tool` / `project`。DB は読み取り専用で開かれます。

| カテゴリ             | 主な原因                           | 対応                                                                                   |
| -------------------- | ---------------------------------- | -------------------------------------------------------------------------------------- |
| `blocked-by-hook`    | 権限拒否、hook による拒否          | 内訳を `sql` で確認する。権限拒否はルールでは減らせない。hook 起因はルールで先回りする |
| `path-not-found`     | パスの推測                         | Glob / `git ls-files` で実在を確認させるルール                                         |
| `command-not-found`  | その環境に無いツール               | `mise ls` / `which` で確認して報告させるルール。常用するなら mise で入れる             |
| `edit-precondition`  | 古い内容のまま Edit                | Read し直してから Edit させるルール                                                    |
| `tool-not-available` | 存在しない、または未ロードのツール | 一覧にあるツールだけ呼ばせる。遅延ロードは ToolSearch で先に読み込む                   |
| `timeout`            | 長時間のコマンド                   | `timeout` を明示、または分割                                                           |
| `cancelled`          | ユーザー停止、並列キャンセル       | 対応不要                                                                               |

#### Bash の `cd` 比率

`doctor` は「Bash の N% が `cd` だけ」も指摘します。毎回 `cd <dir> && ...` を前置している状態なので、
グローバルのルールに「絶対パスか `git -C` を使う」と書くと下がります（このリポジトリでは 46% から 30% に低下）。

#### ルールを足したあとの確認

ルールはどれも毎セッション数百バイトのコンテキストを増やします。足したあとは、数日分のセッションが溜まってから
`cclens doctor` を再実行し、該当カテゴリの件数が減っているかを見ます。減っていなければルールを削ります。

#### プロジェクトのスラッグ

`--scope project:<slug>` の `<slug>` は、`~/.claude/projects/` 配下のディレクトリ名と一致します。
`doctor` の WHAT TO FIX FIRST が、そのまま貼れる形で `--scope project:<slug>` を出してくれます。
fzf で選ぶなら次の関数が使えます。

```zsh
cclens-failures() {
  local slug
  slug=$(ls "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects" \
    | fzf --prompt='project> ' \
          --preview 'cclens failures --scope project:{} --frozen' \
          --preview-window=right:70%) || return
  cclens failures --scope "project:$slug" "$@"
}
```

### データの場所

- 設定ディレクトリ: `CLAUDE_CONFIG_DIR`（空でなければ）、なければ `~/.claude`。
  複数アカウントを使うときは `CLAUDE_CONFIG_DIR=~/.claude-account2 cclens doctor` のようにアカウントごとに実行します。
- DB: `${XDG_STATE_HOME:-~/.local/state}/cclens/cclens.db`。
  Claude Code が transcript を削除した後も履歴が残るため、DB は消さないでください。
- 色は `NO_COLOR` を設定するか、パイプすると無効になります。

### Claude Code plugin（任意）

セッション内から使いたい場合は plugin を入れます。`/cclens:doctor` / `/cclens:optimize` / `/cclens:query` の skill が使えます。

```text
/plugin marketplace add lambdalisue/cclens
/plugin install cclens@cclens
```

## ブラウザ操作（Chrome DevTools MCP と Playwright）

ブラウザを操作させる手段として、Chrome DevTools MCP と Playwright MCP（テストは `dev-webtest` skill が使う
playwright-cli）を用途で使い分けます。両方の MCP を常に読み込むとツール定義でコンテキストを多く使い、
エージェントがどちらを使うか迷う原因にもなるため、作業に合わせて片方だけ有効にするのがおすすめです。

| 観点                                 | Chrome DevTools MCP                              | Playwright                                         |
| ------------------------------------ | ------------------------------------------------ | -------------------------------------------------- |
| ブラウザ操作（クリック・入力・遷移） | ◯                                                | ◎ アクセシビリティツリーでの要素指定が安定している |
| コンソールログ                       | ◎ 一覧とスタックトレースまで取れる               | △ メッセージ一覧が中心                             |
| ネットワーク                         | ◎ リクエスト一覧と各リクエストのヘッダー・ボディ | △ リクエスト一覧が中心                             |
| パフォーマンス                       | ◎ トレース取得、Core Web Vitals・LCP の分析      | ✕                                                  |
| CPU・ネットワークの低速化の再現      | ◯                                                | △                                                  |
| 対応ブラウザ                         | Chrome のみ                                      | Chromium・Firefox・WebKit                          |
| 起動中の Chrome への接続             | ◯ `--browser-url`                                | ◯ `--cdp-endpoint`                                 |
| E2E テストへの流用                   | ✕                                                | ◎                                                  |

### 使い分けの指針

- **デバッグ・調査は Chrome DevTools MCP。** 「ボタンを押すと API が 500 を返す原因を調べて」「コンソールの
  エラーを見て」「表示が遅い理由を調べて」など、人が DevTools を開いてやる作業を任せるときに使います。
- **対話的な画面操作は Playwright MCP。** 「このフォームに入力して送信して」「この手順で画面を進めて」など、
  操作そのものが目的のときに使います。要素をアクセシビリティツリーで指定するので操作が安定します。
- **シナリオ通りのテストは Playwright（skill）。** 画面仕様に沿った動作確認、visual・accessibility・responsive
  の確認、Chrome 以外のブラウザでの確認、テストコードへの落とし込みは `dev-webtest` 系 skill
  （[Web UIをtestする](ai-skill.md#web-uiをtestする)）を使います。

### MCP の設定

sandbox からは `config/sbx/mcp.yml` の `chrome-devtools` と `playwright` を sbx mcp（gateway）経由で使います
（登録は `mise run sandbox:mcp-add`。詳細は [docs/docker-sandboxes.md](./docker-sandboxes.md#mcp-の扱い)）。
どちらもホストで起動している同じ Chrome に CDP で接続する（`chrome-devtools` は `--browser-url`、`playwright` は
`--cdp-endpoint` に `http://localhost:9222` を指定）ので、先にホストでデバッグポート付きの Chrome を起動しておきます。
sandbox へ読み込むときは、作業に合わせて片方だけ指定します（`--static-mcp` / `mise run sandbox:mcp-load`）。

```bash
# macOS
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 --user-data-dir=$HOME/chrome-profiles/profile1 > /dev/null 2>&1 &
```

- `--user-data-dir` を普段のプロファイルと分けておくと、そのプロファイルでログインした状態のまま調査できます。
- 複数の Chrome を並行して使う場合は 9223 / 9224 で起動し、`config/sbx/mcp.work2.yml.example` を参考に
  `chrome-devtools-2` / `chrome-devtools-3` を追加します。
