# ccmanager

[ccmanager](https://github.com/kbwo/ccmanager) は Git worktree ごとに AI エージェントのセッションを管理する TUI です。
設定は `config/ccmanager/config.json` にあります。

## 起動する

zabrze の snippet で起動します。

| trigger | 用途                                                                                              |
| ------- | ------------------------------------------------------------------------------------------------- |
| `ccm`   | ホストで起動                                                                                      |
| `ccmc`  | devcontainer で起動（リポジトリの root で実行。詳細は [`docs/devcontainer.md`](devcontainer.md)） |
| `ccmcm` | multi-worktree の task root を横断管理（`--multi-project`。どこからでも起動できる）               |

`selectPresetOnStart` を有効にしているため、セッション作成時に preset（Claude account1 / account2 / Work3、Codex、Copilot）を選びます。

multi-worktree との組み合わせは [`docs/multi-worktree.md`](multi-worktree.md) の「ccmanager との統合」を参照してください。

## 同じ worktree で複数セッションを立ち上げる

メニューで worktree を Enter で選ぶと、その worktree で動いているセッションがあれば最初の1つにアタッチします。
同じ worktree に追加でセッションを立てるときは Session Actions を使います。

1. 起動済みセッションの**セッション行**にカーソルを合わせる
2. `Space` で Session Actions を開く
3. `S`（New session in same directory）を押す
4. preset 選択画面で preset を選ぶ（同じ preset でも新規セッションとして起動する）

Session Actions では次の操作もできます。

| キー | 操作                                                                                                        |
| ---- | ----------------------------------------------------------------------------------------------------------- |
| `S`  | 同じディレクトリで新規セッションを作成                                                                      |
| `R`  | セッション名を変更（メニューに `パス : 名前` で表示され、同じ worktree の複数セッションを見分けやすくなる） |
| `X`  | セッションを閉じる                                                                                          |

同じディレクトリで複数のエージェントが同時にファイルを編集すると衝突しやすいため、
2つ目以降は調査・レビュー専用にするなど役割を分けて使います。

## tmux で AI セッションを一覧表示する

`prefix → Ctrl+D → AI セッション一覧` で、ホスト上の複数の ccmanager が管理するセッションを
まとめて表示します。ステータスバーにも状態別の件数が出ます。

- `↑` / `↓` で行を選択し、`Enter` で直近の会話を開閉します。
- `/` でセッション名・ブランチ・プロンプトを検索し、`w` で入力待ちだけに絞ります。
- `PgUp` / `PgDn` で会話をスクロールし、`Esc` で閉じます。

配置後は tmux の設定を再読み込みし、新しい ccmanager セッションで状態フックを有効にします。
会話プレビューは、この設定で起動した Docker Sandbox の Claude / Codex が対象です。
Codex でフックの承認が求められた場合は `/hooks` で設定を確認してください。
同じ ccmanager が同じ worktree・preset のセッションを複数起動した場合、状態と名前は各行に
表示されます。会話は ccmanager と sandbox の起動を一意に対応づけられる場合に表示されます。

## Docker Sandbox で Claude アカウントを切り替える

Docker Sandbox の Claude preset は `--claude-account account1/account2/work3` を渡し、
専用 kit と sandbox 固有のサブスク用 token を使います。初回登録が済むまでは起動しません。
設定ディレクトリだけを分ける方式では sbx の共通 OAuth が優先されるためです。

登録・credential binding・旧 sandbox の移行・制約は
[Claude サブスクを account ごとに固定する kit](docker-sandboxes.md#claude-サブスクを-account-ごとに固定する-kit実験的)
を参照してください。sandbox 内で `/login` は使わず、token の更新もホストで行います。
