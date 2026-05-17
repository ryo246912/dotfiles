# DOTFILE-23 実装計画

## 目的とスコープ

- devcontainer から `ssh mac-host "<shell>"` でホストに任意コマンドを流せる状態をやめ、許可した action だけを無人実行できるようにする。
- Claude Code の `Notification` / `Stop` hooks で使っているホスト通知は維持しつつ、未定義 action は実行せず「確認が必要」と分かる形で止める。
- 対象は devcontainer 側の SSH 呼び出し、ホスト側の受け口、`authorized_keys` の登録方法、関連ドキュメント、および local project 向け `AGENTS.md` / `CLAUDE.md` に限定する。

## 現状整理

- `dot_config/devcontainer/devcontainer.json` はホストの `~/.ssh/id_docker_devcontainer` をコンテナ内 `~/.ssh/id_ed25519` としてマウントしている。
- `dot_config/devcontainer/scripts/executable_post-start.sh` は `Host mac-host` を `host.docker.internal` 向けに生成し、devcontainer からホストへ SSH できる前提を作っている。
- `dot_local/bin/executable_multi-worktree` は `.claude/settings.local.json` に `ssh ... mac-host "<shell>"` 形式の hooks を生成しており、通知用とはいえ raw shell をホストに渡している。
- `dot_config/multi-worktree/README.md` は devcontainer 公開鍵を `authorized_keys` に無制限で append する手順になっている。

## 要件

### 機能要件

- ホスト側に forced-command gateway を追加し、`SSH_ORIGINAL_COMMAND` から受け取った allowlist action だけを処理する。
- 初期 allowlist は Claude Code の通知処理に必要な action に限定する。
- 未定義 action や raw shell はホストで実行せず、確認が必要だと分かる通知または明示的な拒否メッセージを返す。
- devcontainer 側の hooks は raw shell ではなく、gateway に渡す構造化リクエストを送る。
- devcontainer 用公開鍵は restricted `authorized_keys` エントリとして登録でき、既存の unrestricted entry から移行できる。
- devcontainer で生成する local project 向け `AGENTS.md` / `CLAUDE.md` に、ホスト実行の制約と許可 action を明記する。

### 非機能要件

- `eval` や `sh -c` に依存せず、安全側に倒れるパースにする。
- 引数は列挙型と短い識別子に制限し、自由文や任意オプションをそのままホストに渡さない。
- 既存の `postStartCommand`、`multi-worktree create/exec`、通知フローを壊さない。

### 制約条件

- 変更対象はこのリポジトリ内の dotfiles / README に限定する。
- 既存の devcontainer 鍵マウントと `mac-host` alias を前提にし、別認証方式には広げない。
- 実装は `Human Review(Plan)` の承認後に開始する。

## 実装アプローチ

### 1. ホスト側 gateway を追加する

- `dot_local/bin` に devcontainer 専用 gateway スクリプトを追加する。
- gateway は `SSH_ORIGINAL_COMMAND` を `action + payload` として解釈し、allowlist にない action は即拒否する。
- 初期対応 action は通知系に絞り、worktree 名、イベント種別、tmux 有無のような最小限の payload だけを受け取る。
- 未定義 action はコマンド文字列をそのまま実行せず、確認が必要だと分かるホスト通知または標準エラーに変換する。

### 2. devcontainer 側の呼び出しを構造化する

- `dot_config/devcontainer/scripts` に gateway 呼び出し用ラッパーを追加するか、既存 `post-start` で生成する規約を定義する。
- `dot_local/bin/executable_multi-worktree` が生成する `.claude/settings.local.json` の hooks を raw shell から structured action 呼び出しへ差し替える。
- `Notification` / `Stop` の文面は host-side gateway 側でテンプレート化し、container 側から自由文を渡さない。

### 3. restricted `authorized_keys` の導線を整える

- README の初回セットアップを、公開鍵の単純 append から `command="..."` 付き restricted entry 追加に更新する。
- 既存の unrestricted entry を置き換える migration 手順を明記する。
- 必要なら gateway スクリプト側に `authorized_keys` 用 1 行を生成するヘルパーを持たせ、再現性を上げる。

### 4. 検証とドキュメントを仕上げる

- allow / deny / confirm-needed の 3 パターンで SSH 実行結果を確認する。
- `multi-worktree create <task>` 後の `.claude/settings.local.json` が gateway 経由になっていることを確認する。
- `multi-worktree create <task>` 後に `AGENTS.md` / `CLAUDE.md` が生成され、allowlist 制御の説明が入ることを確認する。
- devcontainer 内で Notification / Stop 相当の呼び出しを行い、ホスト通知が維持されることを確認する。
- README にセットアップ、migration、検証コマンドを追記する。

## 変更対象ファイル

- `dot_local/bin/executable_multi-worktree`
- `dot_local/bin/executable_devcontainer-host-gateway`（新規）
- `dot_config/devcontainer/scripts/executable_post-start.sh`
- `dot_config/devcontainer/scripts/executable_devcontainer-host-action.sh`（新規、必要な場合）
- `dot_config/multi-worktree/README.md`
- `dot_config/multi-worktree/templates/local-project-AGENTS.md`（新規）
- `dot_config/multi-worktree/templates/local-project-CLAUDE.md`（新規）

## 検証方法

- `ssh -F ~/.config/ssh/config mac-host notify --event pending --worktree sample --tmux 0` が成功する。
- `ssh -F ~/.config/ssh/config mac-host /bin/echo blocked` が非ゼロで拒否される。
- `ssh -F ~/.config/ssh/config mac-host unknown-action` が確認要求の通知または明示的な拒否メッセージを返す。
- `multi-worktree create <task>` 後の `.claude/settings.local.json` に raw shell ではなく gateway 呼び出しが書かれる。
- `multi-worktree create <task>` 後に `AGENTS.md` / `CLAUDE.md` が生成され、ホスト実行の制約が明記される。
- devcontainer 内で Notification / Stop 相当を実行し、ホスト通知が表示される。

## リスクと未解決事項

- `SSH_ORIGINAL_COMMAND` のパース方法が甘いと quote / injection の新たな抜け道になるため、payload 形式は shell eval なしで扱える形に固定する必要がある。
- 「未定義コマンドはユーザー確認を求める」の UX は実装詳細の詰めが必要で、今回は少なくとも「実行せず、確認が必要だと分かる通知を出す」ラインで設計する。
- ホスト側 `authorized_keys` に既存 unrestricted entry が残ると bypass できるため、migration 手順で置換を明示する必要がある。
