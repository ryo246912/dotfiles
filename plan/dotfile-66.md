# DOTFILE-66 GitHub ruleset の調査と ruleset-only 方針の Python 実装

## 概要

- `dot_local/bin/executable_setup-github` を、default branch の保護を ruleset だけで表現する `uv run --script` の Python script として整理する。
- 対象リポジトリは `ryo246912/lazychezmoi` と `ryo246912/dotfiles` の `main`。
- 最新コメントを受け、classic branch protection の削除や更新はこの ticket の script スコープから外し、`Settings > Rules` / `Settings > Branches` の監査だけ継続する。

## 要件

### 機能要件

- script は default branch ruleset を `active` で作成または更新できること。
- ruleset の bypass actor に `RepositoryRole` の admin を `pull_request` モードで設定し、admin だけが PR 経由でセルフマージできること。
- ruleset の pull request rule は `approval 1 / dismiss stale reviews / last push approval / code owner review false / review thread resolution false / allowed merge methods = merge,squash` を満たすこと。
- script は classic branch protection を新規作成・更新・削除しないこと。
- `ryo246912/lazychezmoi` と `ryo246912/dotfiles` の `Settings > Rules` / `Settings > Branches` / effective rules を監査し、malicious collaborator を想定した妥当性を説明できること。
- `CODEOWNERS` の有無に依存せず、admin bypass を ruleset で表現すること。

### 非機能要件

- default branch への direct push や review なし merge を非 bypass actor に許さないこと。
- 単独管理 repo で owner/admin 自身が merge 条件を満たせない自己矛盾を作らないこと。
- `gh api` ベースで再実行しても同じ ruleset 設定に収束しやすいこと。

### 制約条件

- 作業はこの repo copy のみで行う。
- Plan 承認前に `dot_local/bin/executable_setup-github` の未承認差分へ追加実装しない。
- `pull` skill はこのセッションにないため、同期確認は `git ls-remote` で代替記録する。
- personal repo では classic branch protection の bypass list を使えない前提で設計する。

## 調査結果

### 現在の remote 設定

- `lazychezmoi` と `dotfiles` の `main` ruleset はどちらも `active` で、`bypass_actors=[{actor_id:5, actor_type:"RepositoryRole", bypass_mode:"pull_request"}]` を持つ。
- effective rules API (`GET /repos/{owner}/{repo}/rules/branches/main`) では、両 repo とも `creation / deletion / non_fast_forward / required_linear_history / required_signatures / pull_request` が ruleset 由来で有効になっている。
- `GET /repos/{owner}/{repo}/branches/main/protection` は両 repo で classic branch protection も返しており、`required_approving_review_count=1 / require_last_push_approval=true / dismiss_stale_reviews=true / required_conversation_resolution=false / enforce_admins=false` が並行して残っている。
- `dotfiles` には `master` 名の active ruleset (`id=3905723`) が残っているが、`conditions.ref_name.include=[]` のため `main` の effective rules には出ていない。
- `lazychezmoi` と `dotfiles` の両方で `CODEOWNERS` は見当たらない。

### ローカル script 差分の再現シグナル

- 以前の bash 実装では ruleset JSON を文字列で組み立てており、レビューコメントの「宣言的に」「Bun の TypeScript か uv の Python も検討してほしい」に対してまだ読みやすさの改善余地が残っていた。
- 既存 path を維持しつつ単一ファイルで運用できること、JSON payload と `gh api` の責務分離を素直に書けることから、今回は `uv run --script` の Python を採用する。
- 置き換え後も classic branch protection の更新経路は追加せず、ruleset-only 方針と remote の保護条件を維持する必要がある。

### GitHub 仕様上の判断材料

- classic branch protection は admin や bypass 権限を持つ role に対する説明が分かりにくく、personal repo で「admin だけ PR 経由でセルフマージ可能」を素直に表現しづらい。
- ruleset は `RepositoryRole` を bypass actor にでき、`pull_request` モードなら direct push を許さず PR merge だけ例外にできる。
- personal repo では classic branch protection の bypass list を使えないため、admin bypass の主表現は ruleset 側が適切。

## 実装計画

### 1. `setup-github` を ruleset-only の Python 実装へ置き換える

- 既存 path `dot_local/bin/executable_setup-github` は維持したまま、shebang を `uv run --script` に切り替える。
- repository settings と ruleset payload を Python の dict で宣言的に表現し、`gh api` 呼び出しだけを薄い helper にまとめる。
- `RepositoryRole(admin) + pull_request` bypass、`allowed_merge_methods=[merge,squash]`、optional required status checks の扱いは維持する。

### 2. remote 監査の観点を ruleset 中心に固定する

- `lazychezmoi` と `dotfiles` の `main` について、ruleset と effective rules が期待値どおりであることを再確認する。
- `Settings > Branches` に classic branch protection が残っていること自体は Notes に残すが、この ticket では script から触らない前提で整理する。
- `dotfiles` の `master` 残骸 ruleset は `main` 保護へ効いていないことを証跡付きで記録する。

### 3. 検証証跡を plan と workpad に残す

- remote の `rulesets/<id>` と `rules/branches/main` を ruleset の証跡として残す。
- `branches/main/protection` は「classic branch protection が並行で存在する監査結果」として扱い、script の変更対象ではないことを明記する。
- `CODEOWNERS` 不在でも admin bypass を ruleset で設計する理由を、GitHub 仕様と現設定に結び付けて記録する。
- sandbox では `uv` と `py_compile` の既定 cache 先が書けないため、検証コマンドでは `/tmp` 配下の cache override を使う。

## 変更対象ファイル

- `dot_local/bin/executable_setup-github`
- `plan/dotfile-66.md`
- `setup.md`（ruleset-only 方針の説明が必要になった場合のみ）

## 検証方法

- `git ls-remote origin refs/heads/main`
- `git diff -- dot_local/bin/executable_setup-github`
- `env PYTHONPYCACHEPREFIX=/tmp/python-pycache python3 -m py_compile dot_local/bin/executable_setup-github`
- `env UV_CACHE_DIR=/tmp/uv-cache ./dot_local/bin/executable_setup-github --help`
- `env UV_CACHE_DIR=/tmp/uv-cache ./dot_local/bin/executable_setup-github ryo246912/lazychezmoi`
- `env UV_CACHE_DIR=/tmp/uv-cache ./dot_local/bin/executable_setup-github ryo246912/dotfiles`
- `gh api repos/ryo246912/lazychezmoi/rulesets/14373599`
- `gh api repos/ryo246912/lazychezmoi/rules/branches/main`
- `gh api repos/ryo246912/lazychezmoi/branches/main/protection`
- `gh api repos/ryo246912/dotfiles/rulesets/11535739`
- `gh api repos/ryo246912/dotfiles/rulesets/3905723`
- `gh api repos/ryo246912/dotfiles/rules/branches/main`
- `gh api repos/ryo246912/dotfiles/branches/main/protection`
- 実装後の期待値:
  - `setup-github` は Python 実装へ置き換わるが ruleset を更新するだけで classic branch protection API を叩かない
  - `rulesets/<id>` に admin `RepositoryRole` bypass と PR review 条件が残る
  - `rules/branches/main` に ruleset 由来の `pull_request` / `non_fast_forward` / `required_linear_history` / `required_signatures` が残る
  - `branches/main/protection` は監査対象としてのみ扱い、script の副作用で変化しない

## リスクと未解決点

- `uv run --script` と `py_compile` は sandbox の既定 cache 先に書けないため、検証時に `/tmp` への環境変数 override を忘れると false negative が出る。
- `Settings > Branches` に classic branch protection が残り続けると、UI 上は ruleset と二重に見える。今回の script 変更はその状態を解消しないため、説明責任は監査ノート側に寄る。
- `dotfiles` の `master` 残骸 ruleset をこの ticket で消すとスコープが広がるため、今回の plan では調査記録に留める。
