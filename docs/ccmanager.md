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
