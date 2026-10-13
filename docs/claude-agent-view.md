# Claude Code agent view（バックグラウンドセッション）

Claude Code には、1 つの画面から複数のセッションを起動・監視・切り替えできる
**agent view** があります（research preview）。空のプロンプトで `←` を押すと出てくる
セッション一覧がこれです。公式ドキュメントは [Agent view](https://code.claude.com/docs/en/agent-view)。

> [!NOTE]
> 「同じ claude プロセスの中で別セッションを開く」機能ではありません。
> 各セッションは **supervisor（バックグラウンドサービス）配下の別々の Claude Code プロセス**として動きます。
> 1 つの画面から操作できるだけで、プロセスや隔離環境が共有されるわけではありません。
> リソースの話は [sandbox ごとに起動する場合との比較](#sandbox-ごとに起動する場合との比較) を参照。

## 開く・閉じる

| 操作                                         | 方法                                                                           |
| -------------------------------------------- | ------------------------------------------------------------------------------ |
| agent view を開く                            | `claude agents`（`--cwd <dir>` でそのディレクトリ配下のセッションだけに絞る）  |
| 今の会話をバックグラウンドに回して一覧を開く | 空のプロンプトで `←`、または `/bg`（`/background`）                            |
| 今の会話をコピーして別セッションで並走させる | `/fork`（元の会話はそのまま続く）                                              |
| 一覧から抜ける                               | `Esc`（セッションは止まらない）                                                |
| `claude` 単体で agent view を開くようにする  | `/config defaultToAgentsView=true`                                             |
| `←` で一覧に飛ぶ挙動を止める                 | 設定 `leftArrowOpensAgents: false`                                             |
| agent view 自体を無効化                      | 設定 `disableAgentView: true`、または環境変数 `CLAUDE_CODE_DISABLE_AGENT_VIEW` |

`←` で一覧に移ると、そのセッションの行が選択された状態になります。`Esc` で会話に戻るか、
`Enter` で開き直せます。ツール実行中は 10 秒ほど待ってから切り替わり、権限プロンプトや
入力途中のテキストがあると切り替わらないことがあります。

## 一覧の操作

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

## 新しいセッションを起動する（dispatch）

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

### 権限モード

- `←` / `/bg` でバックグラウンドに回したセッションは、今の権限モードをそのまま引き継ぎます。
- 一覧から dispatch したセッションは、対象ディレクトリの `permissions.defaultMode` が使われます。
  ただし `auto` / `bypassPermissions` はユーザー設定（`~/.claude/settings.json`）・managed settings・
  `--settings` で指定したときだけ有効で、プロジェクト設定からは選べません。
- `claude agents --dangerously-skip-permissions` のように、開くときのフラグで既定を渡すこともできます。

## ファイル編集の隔離（worktree）

一覧や `--bg` から dispatch したセッションは、ファイルを編集する前に
`.claude/worktrees/` 配下に**専用の git worktree を作ってそこへ移動**します。
並列セッションが同じファイルを書き合わないための仕組みです。次の場合は worktree を作りません。

- `←` / `/bg` で、すでに開いていたセッションをバックグラウンドに回したとき
- すでに linked worktree の中にいるとき（`multi-worktree` の worktree はこれに当たる）
- git リポジトリではなく、`WorktreeCreate` hook も無いとき

worktree を作らせたくない場合は設定で無効化できます。

```json
{
  "worktree": {
    "bgIsolation": "none"
  }
}
```

一覧から削除すると **Claude が作った worktree も未コミットの変更ごと消えます。** 残したいものは
先にコミット・push しておきます（未 push のコミットがある worktree は削除がブロックされます）。

## スクリプトから操作する

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

### 複数アカウントとの関係

`CLAUDE_CONFIG_DIR` を設定していると、supervisor はその設定ディレクトリを使う**別インスタンス**として
動きます。[`docs/ai.md`](ai.md) の account2 / work3 のように `CLAUDE_CONFIG_DIR` を切り替えて
起動している場合、agent view の一覧もアカウントごとに分かれます。

## プロセスの仕組み

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

## sandbox ごとに起動する場合との比較

このリポジトリでは `multi-worktree dev` で **セッションごとに sbx sandbox（microVM）** を作っています
（[`docs/docker-sandboxes.md`](docker-sandboxes.md)）。agent view に寄せるとリソース的に得か、の整理です。

### 結論

- **Claude Code のプロセス自体のコストはほぼ変わりません。** agent view でもセッションごとに
  別プロセスなので、「1 プロセスに相乗りして軽くなる」ことはありません。
- **差が出るのは sandbox（microVM）の数です。** sbx は sandbox ごとに VM・専用 kernel・
  専用 docker daemon・image store（template 数 GB）を持つため、並列数 N に比例して重くなります。
  agent view でまとめれば、この VM 側の N 倍が消えます。
- ただし **ホストで `claude agents` を使うと sandbox の隔離（ネットワーク制御・secret 注入・
  FS の露出制限）が丸ごと無くなります。** `--dangerously-skip-permissions` 前提の運用では
  ここが一番大きな差なので、単純に置き換えるのはおすすめしません。

| 観点                    | セッションごとに sandbox      | ホストで agent view                  | 1 つの sandbox の中で agent view      |
| ----------------------- | ----------------------------- | ------------------------------------ | ------------------------------------- |
| Claude Code プロセス    | N 個                          | N 個 + supervisor                    | N 個 + supervisor                     |
| VM / docker daemon      | N 個                          | 0                                    | 1 個                                  |
| ディスク（template 等） | N 個分                        | 0                                    | 1 個分                                |
| アイドル時の回収        | 無し（`sbx stop` を手で打つ） | 約 1 時間でプロセス停止              | プロセスは停止、VM は残る             |
| 隔離                    | セッション間も VM で分離      | 無し（Claude Code の権限設定だけ）   | ホストとは分離、セッション間は同じ VM |
| ファイル衝突の回避      | `multi-worktree` の worktree  | `.claude/worktrees/` に自動 worktree | 同左                                  |

### 使い分けの指針

- **安全性を優先する重い実装タスク**: これまで通りセッションごとに sandbox。
  並列させるときは `--cpus` / `--memory` を絞る。
- **同じタスク（同じ sandbox）の中で調査・レビューを並走させたい**: sandbox の中で
  `←` / `/bg` / `claude agents` を使う。VM は 1 つのまま、Claude のセッションだけ増やせます。
  sandbox の中では workspace だけが見えるので隔離はホストとの間で保たれ、増えるのは
  プロセス分のメモリだけです。ただし同じ VM 内のセッション同士は分離されないので、
  同じファイルを触る作業は worktree を分けます（`multi-worktree` の worktree の中では
  自動 worktree が作られない点に注意）。
- **隔離が要らない軽い作業**（ドキュメント調査・質問など）: ホストで `claude agents` から dispatch。
  VM を立てるより圧倒的に軽量です。

> [!NOTE]
> sandbox の中で agent view を使う構成は、この環境ではまだ動作確認していません。
> 使う場合、supervisor は sandbox の中で動きます。
> `sbx stop` すると sandbox 内のセッションもすべて止まり、ホストの `claude agents` からは見えません。

## 注意点

- バックグラウンドセッションも通常どおり使用量を消費します。10 並列なら 10 倍の速さで枠を使います。
- セッションは別プロセスなので、増やしすぎるとメモリが枯渇します（`possibly low memory` で失敗する）。
- dispatch したセッションはコード変更をコミット・push するよう指示されています
  （`main` / `master` への push・force-push・merge はしない）。
- `claude agents` がセッション一覧ではなく subagent の一覧を出す場合は、agent view が使えない古い版です。`claude update` で更新します。

## 参考

- [Manage agents with agent view](https://code.claude.com/docs/en/agent-view)
- [Run agents in parallel](https://code.claude.com/docs/en/agents)
