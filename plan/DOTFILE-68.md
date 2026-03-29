# DOTFILE-68 multi-worktree の各 task を ccmanager で横断管理できるようにする計画

## 概要

- 現在の `multi-worktree create <task>` は、task root 配下に各 repo の git worktree と `.devcontainer` を作るが、task root 自体は git repository ではない。
- そのため `ccmanager` は task root を project として認識できず、1 task 単位でも複数 task 横断でも `ccmanager` から管理しづらい。
- 2026-03-29 時点の要件は、次の 2 つを同時に満たすことだと整理した。
  - task root 上で `ccmanager` / `ccmc` を起動できること
  - `multi-worktree` で作った複数 task を `ccmanager --multi-project` でまとめて見られること
- `ccmanager` の公式 docs と実装を確認した結果、multi-project discovery は「`.git` ディレクトリを持つ directory」を project として収集し、最初に見つけた git project 配下は再帰探索しない。したがって、task root を通常の `.git` ディレクトリ付き repository として初期化する案が、要件と実装量のバランスが最も良い。

## 目的とスコープ

- 目的:
  - multi-worktree の各 task root を `ccmanager` が認識できる project にする。
  - group ごとの task 群を `CCMANAGER_MULTI_PROJECT_ROOT=<base_dir> ccmanager --multi-project` で横断管理できるようにする。
  - 既存の `multi-worktree cd <task>` 導線を維持し、単体 task でも `ccmanager` / `ccmc` を起動できるようにする。
- 今回の計画で決めること:
  - `ccmanager` fork / この repo での bootstrap / 独自ツール作成の比較
  - 実装する場合の変更範囲、検証方法、主要リスク
- 今回の計画でやらないこと:
  - 実コードの変更
  - upstream `ccmanager` へのコントリビュートや fork 管理
  - `ccmanager` 相当の新規 TUI / session manager の自作

## 要件

### 機能要件

- `multi-worktree create <task>` 後の task root が git repository として認識されること。
- task root のブランチ名が `multi-worktree-<task>` になること。
- 配下 repo の worktree ブランチ名は従来どおり `<task>` を維持すること。
- task root で `ccmanager` / `ccmc` を直接起動できること。
- 同一 group の `base_dir` を `CCMANAGER_MULTI_PROJECT_ROOT` に向けたとき、各 task root が `ccmanager --multi-project` の project 一覧に並ぶこと。
- 既存の `list` / `status` / `sync` / `cd` / `exec` / `open` / `remove` の挙動を壊さないこと。

### 非機能要件

- 変更はこの repository 内で完結すること。
- 既存の bash script 中心の構成を大きく崩さないこと。
- bootstrap は idempotent で、同じ task に対する再実行や途中失敗後の再実行で壊れにくいこと。
- README だけで「single-task の起動方法」と「multi-project での起動方法」の両方が追えること。

### 制約条件

- task root は現状 `.git` を持たない。
- `ccmanager` の per-project config は git repository root 前提である。
- `ccmanager` の multi-project mode では `.ccmanager.json` が無効で、global config のみが使われる。
- group ごとに `base_dir` が異なりうるため、multi-project root は group 単位で考える必要がある。
- shell script 用の自動テスト基盤は現状ないため、検証は fixture + smoke test が中心になる。

## 調査結果

### この repo 側

- [`dot_local/bin/executable_multi-worktree`](../dot_local/bin/executable_multi-worktree) の `cmd_create` は配下 repo の worktree 作成と `.devcontainer` 生成までを担当し、task root の git 初期化はしていない。
- 同スクリプトの `find_worktree_dir` / `cmd_list` は task root directory を group ごとの `base_dir` 配下から見つけているので、task root 自体が project になれば既存管理導線をそのまま使える。
- [`dot_config/zabrze/ai.toml`](../dot_config/zabrze/ai.toml) には `ccmanager` / `ccmc` の既存スニペットがあり、single-task 起動は新コマンドを追加しなくても運用できる。
- [`dot_local/bin/executable_git-worktree-manager`](../dot_local/bin/executable_git-worktree-manager) は task 一覧表示や tmux/fzf 操作は持つが、`ccmanager` の session 管理代替にはなっていない。

### upstream `ccmanager` 側

- 公式 README では per-project config の配置先を「git repository root の `.ccmanager.json`」としている。
- `docs/project-config.md` では、multi-project mode では per-project config は使われず global config のみ使うと明記されている。
- `docs/multi-project.md` では、multi-project discovery は root 配下を再帰探索し、git worktree を除外すると説明されている。
- `src/services/projectManager.ts` では、`discoverProjectsInDirectory` が `.git` ディレクトリを持つ directory を project として採用し、その時点で子孫 directory の探索を止める実装になっている。
- この実装から、task root に通常の `.git` ディレクトリを置けば:
  - task root が project として一覧化される
  - 配下の child repo worktree までは project discovery が降りない
  - `multi-worktree` task 単位の一覧化に都合が良い
  と推論できる。

## 代替案

### 案1: upstream `ccmanager` を fork して workspace-root mode を追加する

- 実装イメージ:
  - non-git directory を first-class project として扱う mode を `ccmanager` 側に追加する。
  - multi-project discovery に task grouping を持たせ、`.git` がなくても task root を project として収集できるようにする。
  - multi-project mode でも project-specific override を扱えるよう、config 読み込みモデルを広げる。
- 利点:
  - task root を本当に first-class entity として扱える。
  - synthetic git の適応レイヤーが不要になる。
  - CCManager UI 側で task project に不要な worktree 操作を隠せる可能性がある。
- 欠点:
  - 変更箇所がこの repo 外に広がる。
  - discovery / config / UI / test まで広く触る必要がある。
  - upstream 方針と release timing に依存する。
- 評価:
  - 長期案としては筋が良いが、この ticket の first implementation としては重い。

### 案2: `multi-worktree create` 時に task root を通常の git repository として bootstrap する

- 実装イメージ:
  - `cmd_create` 成功後に task root で `git init` し、通常の `.git` ディレクトリを作る。
  - `multi-worktree-<task>` ブランチを作り、空コミットで branch を固定する。
  - repo-local config (`status.showUntrackedFiles=no` など) を入れて child repo 群がノイズになりにくい状態にする。
  - single-task は従来どおり `multi-worktree cd <task>` 後に `ccmanager` / `ccmc` を起動する。
  - multi-task は group の `base_dir` を `CCMANAGER_MULTI_PROJECT_ROOT` に向けて `ccmanager --multi-project` を起動する。
- 利点:
  - 変更がこの repo に閉じる。
  - task root の single-task / multi-task 両方の要件を一つの仕組みで満たせる。
  - `ccmanager` の project discovery が task root で止まるため、child repo が project 一覧に混ざらない。
  - 既存の `ccmanager` / `ccmc` スニペット資産をそのまま使える。
- 欠点:
  - task root が擬似的に本物の git repository として見える。
  - `ccmanager` の worktree 操作を task root に対して実行すると意味の薄い操作が残る。
  - multi-project mode では `.ccmanager.json` が効かないため、細かな task ごとの差分設定はできない。
- 評価:
  - 今回の本命。要件と変更量のバランスが最も良い。

### 案3: multi-worktree 専用の session manager をこの repo で自作する

- 実装イメージ:
  - task root 一覧、session 起動、再接続、状態表示をこの repo の script として独自実装する。
  - 初期版は `fzf` / `tmux` ベースでもよいが、将来的には `ccmanager` 相当の状態監視が必要になる。
- 利点:
  - task root を最初から first-class に設計できる。
  - `ccmanager` の git 前提や multi-project 制約に縛られない。
- 欠点:
  - session persistence / state 表示 / command preset などを再実装する必要がある。
  - 維持コストがこの repo 側に残り続ける。
- 評価:
  - 案2 が運用上破綻した場合の fallback としては有力だが、初手としては過剰。

## 推奨アプローチ

- 採用案: 案2
- 理由:
  - task root を project 化することで single-task / multi-task の両要件を同時に満たせる。
  - `ccmanager` の実装上、task root に `.git` ディレクトリを置くと project discovery がそこで止まるため、一覧が task 単位に保てる。
  - `ccmanager` 本体を fork せず、この repo 内の変更だけでまず価値を出せる。

## 実装方針

### 1. `cmd_create` に task root bootstrap を追加する

- repo worktree 作成と `.devcontainer` 生成が終わった後、task root を対象に `ensure_task_root_git_project` 相当の helper を呼ぶ。
- helper は以下を担当する:
  - task root に通常の `.git` ディレクトリを作る
  - `multi-worktree-<task>` ブランチを作る
  - 空コミットを作って branch を固定する
  - `status.showUntrackedFiles=no`、必要なら `advice.detachedHead=false` などの repo-local config を設定する
  - 再実行時に branch / config / commit が壊れないよう idempotent にする

### 2. 起動導線は `cd` と `--multi-project` の 2 系統だけに整理する

- single-task:
  - `multi-worktree cd <task>`
  - `ccmanager` または `ccmc`
- multi-task:
  - group の `base_dir` を `CCMANAGER_MULTI_PROJECT_ROOT` に向ける
  - `ccmanager --multi-project` または `ccmc --multi-project`
- `multi-worktree ccmanager <task>` のような専用 wrapper は追加しない。
- 既存 `dot_config/zabrze/ai.toml` は原則そのまま使い、README で利用例だけ補う。

### 3. README を更新する

- [`dot_config/multi-worktree/README.md`](../dot_config/multi-worktree/README.md) に以下を追加する:
  - task root に `.git` ディレクトリを作る理由
  - task root の branch 名が `multi-worktree-<task>` であること
  - single-task 起動手順
  - multi-task 起動手順 (`CCMANAGER_MULTI_PROJECT_ROOT=<base_dir> ... --multi-project`)
  - multi-project mode では `.ccmanager.json` が効かず global config を使うこと
- 既存の `exec ... ccmanager` 例は「devcontainer 内で単発実行する用途」と「task を ccmanager の project として扱う用途」が混同しないよう書き換える。

### 4. fixture と smoke test で検証する

- 一時 fixture で同じ group / base_dir 配下に複数 task を作る。
- `multi-worktree create feat/a` / `multi-worktree create feat/b` 後に以下を確認する:
  - 各 task root に `.git` ディレクトリがある
  - `git -C <task-root> branch --show-current` が `multi-worktree-<task>` を返す
  - child repo worktree のブランチは従来どおり `<task>` のまま
- group の `base_dir` に対して以下を確認する:
  - task root 数と `.git` ディレクトリ数が一致する
  - task root 直下の child repo worktree は `.git` file であり、task root 自体の `.git` directory とは区別されている
- `ccmanager` が利用可能なら、`CCMANAGER_MULTI_PROJECT_ROOT=<base_dir> ccmanager --multi-project` を smoke 実行し、task root が project として見えることを目視確認する。
- 回帰として `list` / `status` / `cd` / `exec` / `open` / `remove` の代表ケースを確認する。

## 想定運用イメージ

- 前提:
  - group ごとに `base_dir` があり、その配下に `multi-worktree-<task>` ディレクトリが task root として並ぶ。
- single-task 管理:
  - `multi-worktree cd feat/add-auth`
  - task root に移動した状態で `ccmanager` または `ccmc`
- multi-task 横断管理:
  - `CCMANAGER_MULTI_PROJECT_ROOT=<base_dir> ccmanager --multi-project`
  - `CCMANAGER_MULTI_PROJECT_ROOT=<base_dir> ccmc --multi-project`
- 補足:
  - `--multi-project` の起動位置は任意でよく、discovery 対象は `CCMANAGER_MULTI_PROJECT_ROOT` で明示する想定。
  - group をまたいで一覧化したい場合は別課題で launcher 集約を検討し、初期実装では group 単位の `base_dir` ごとに扱う。

## 変更対象ファイル

- [`dot_local/bin/executable_multi-worktree`](../dot_local/bin/executable_multi-worktree)
- [`dot_config/multi-worktree/README.md`](../dot_config/multi-worktree/README.md)

## 検証方法

- 構文確認:
  - `bash -n dot_local/bin/executable_multi-worktree`
- bootstrap 確認:
  - fixture 上で `multi-worktree create <task>` を実行し、task root に `.git/` ができることを確認する
  - `git -C <task-root> branch --show-current` が `multi-worktree-<task>` になることを確認する
- multi-project 前提確認:
  - 同一 `base_dir` に task を 2 件以上作り、`.git/` を持つ task root が列挙されることを確認する
  - `CCMANAGER_MULTI_PROJECT_ROOT=<base_dir> ccmanager --multi-project` の smoke を可能なら実行する
- 回帰確認:
  - `multi-worktree help`
  - 既存の `list` / `status` / `cd` / `exec` / `open` / `remove` の代表ケース

## リスクと対応策

- リスク: task root が通常の git repository として見えることで、他ツールが本物の repo と誤認する。
  - 対応: README で synthetic repository であることを明示し、repo-local config でノイズを抑える。
- リスク: `ccmanager` の worktree 操作を task root に対して使うと、不自然な branch/worktree が増える。
  - 対応: README で supported use-case を「task root session 管理」と「task 群一覧化」に絞って明記する。
- リスク: multi-project mode では `.ccmanager.json` が効かず、task ごとの差分設定ができない。
  - 対応: 初期実装は global config 前提で割り切り、必要になれば follow-up issue で launcher / preset 分離を検討する。
- リスク: group ごとに `base_dir` が分かれているため、全 task を 1 画面にまとめたい要求には直結しない。
  - 対応: まずは group 単位で成立させ、必要なら follow-up で root 集約 launcher を検討する。

## 未解決事項

- `.ccmanager.json` を single-task 用にだけ使う余地を今回スコープに含めるか。
- group 跨ぎの task 一覧化が必要か。それともまずは group 単位の multi-project で十分か。
- task root 向け repo-local config をどこまで入れるか (`status.showUntrackedFiles=no` 以外も必要か)。

## 参考資料

- `ccmanager` README: <https://github.com/kbwo/ccmanager>
- `ccmanager` multi-project docs: <https://github.com/kbwo/ccmanager/blob/main/docs/multi-project.md>
- `ccmanager` project config docs: <https://github.com/kbwo/ccmanager/blob/main/docs/project-config.md>
- `ccmanager` project discovery 実装: <https://raw.githubusercontent.com/kbwo/ccmanager/main/src/services/projectManager.ts>
- この repo の関連実装:
  - [`dot_local/bin/executable_multi-worktree`](../dot_local/bin/executable_multi-worktree)
  - [`dot_local/bin/executable_git-worktree-manager`](../dot_local/bin/executable_git-worktree-manager)
  - [`dot_config/multi-worktree/README.md`](../dot_config/multi-worktree/README.md)
  - [`dot_config/zabrze/ai.toml`](../dot_config/zabrze/ai.toml)

## 2026-03-30 追加スコープ: `recreate` コマンド

### 目的と背景

- 直近コメントで、`multi-worktree recreate <task>` を追加し、「現在の config 内容で不足している worktree は補充しつつ、`devcontainer.json` と `.claude/settings.local.json` は current config で上書き再生成する」挙動が求められた。
- 想定ユースケースは以下:
  - group の `repos` に新しいリポジトリを追加したあと、既存 task にその repo worktree だけを足したい
  - task root 配下の `.git/` が欠けたので補修したい
  - group の `repos` や `devcontainer` mount 対象を変えたあと、既存 task の generated settings を current config に合わせて更新したい
  - 既存の repo worktree は保持したいが、generated settings は再出力したい

### 実装アプローチ

- `create` と同じ branch 解決 / `git worktree add` ロジックを helper 化し、`recreate` でも再利用する
- `recreate` の group 解決は:
  - `--group` 指定があればそれを優先
  - 未指定なら既存 task directory から group を推定
  - それも無ければ default group を使う
- repo worktree は「path が存在しないものだけ」作成する
- task root support files は以下の方針で扱う
  - synthetic git repository (`.git/` と task root branch) は欠けているときだけ補修する
  - `.devcontainer/devcontainer.json` は `recreate` のたびに current config で上書き再生成する
  - `.claude/settings.local.json` は `recreate` のたびに current config で上書き再生成する

### 変更対象ファイル

- [`dot_local/bin/executable_multi-worktree`](../dot_local/bin/executable_multi-worktree)
- [`dot_config/multi-worktree/_multi-worktree`](../dot_config/multi-worktree/_multi-worktree)
- [`dot_config/multi-worktree/completion.bash`](../dot_config/multi-worktree/completion.bash)
- [`dot_config/multi-worktree/README.md`](../dot_config/multi-worktree/README.md)

### 検証方法

- 構文確認:
  - `bash -n dot_local/bin/executable_multi-worktree`
  - `zsh -n dot_config/multi-worktree/_multi-worktree`
  - `bash -n dot_config/multi-worktree/completion.bash`
- fixture 確認:
  - 初期 config で task を作成する
  - config に repo を追加したうえで `recreate` を実行し、新規 repo worktree だけ増えることを確認する
  - 既存 repo worktree path が残ったまま `recreate` し、削除・再作成されないことを確認する
  - 既存 `devcontainer.json` / `settings.local.json` を変更した状態で `recreate` し、current config の内容で上書き再生成されることを確認する
  - `task root` の `.git/` を削除して `recreate` し、synthetic git repository だけ補修されることを確認する
- 回帰確認:
  - `multi-worktree help`
  - `multi-worktree list`
  - `multi-worktree status <task>`
  - `multi-worktree exec <task> pwd`

### リスクと対応策

- リスク: `recreate` が `devcontainer.json` / `.claude/settings.local.json` を上書きするため、手編集した内容が消える
  - 対応: README に generated file であることを明記し、手編集を残したい場合は別 file / 別運用に逃がす前提にする
- リスク: task 名だけで group を推定すると、複数 group に同名 task がある場合は曖昧になる
  - 対応: `--group` を優先し、README でも明示する
