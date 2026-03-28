# DOTFILE-66 GitHub ruleset とデフォルトブランチ保護の見直し

## 概要

- `dot_local/bin/executable_setup-github` を、public な personal repository 向けに「非 admin には review を要求しつつ、admin 自身は PR 経由でセルフマージできる」default policy へ更新する。
- 対象リポジトリは `ryo246912/lazychezmoi` と `ryo246912/dotfiles` の default branch `main`。
- GitHub の `Settings > Rules` だけでなく `Settings > Branches` の classic branch protection も整合させ、未解決会話を必須にしない要件まで含めて揃える。

## 要件

### 機能要件

- default branch ruleset を `active` で作成または更新できること。
- ruleset の bypass actor に `RepositoryRole` の admin を `pull_request` モードで設定し、admin だけが PR 経由で自己責任セルフマージできること。
- ruleset の pull request rule は `approval 1 / dismiss stale reviews / last push approval / code owner review false / review thread resolution false / allowed merge methods = merge,squash` を満たすこと。
- classic branch protection でも `approval 1 / dismiss stale reviews / last push approval / conversation resolution false` を default branch に適用し、`Settings > Branches` の表示も意図と一致させること。
- required status checks は default で空のままとし、always-on workflow がある場合のみ opt-in できる拡張点を残すこと。
- `ryo246912/lazychezmoi` と `ryo246912/dotfiles` の ruleset / branch protection / merge settings を監査し、現在値と最終判断を説明できること。

### 非機能要件

- malicious collaborator を想定しても、default branch へ direct push や review なし merge を許さないこと。
- 単独管理 repo で owner/admin 自身が merge 条件を満たせない自己矛盾を作らないこと。
- `gh api` ベースで再実行しても同じ設定に収束すること。

### 制約条件

- 作業はこの repo copy のみで行う。
- sandbox 制約で `git fetch origin main` が失敗するため、pull 同期は `git ls-remote` と compare API で代替確認する。
- personal repo では classic branch protection の bypass list ではなく、ruleset bypass actor を主軸に設計する。

## 実装方針

### 1. `setup-github` の default policy を見直す

- `ENFORCEMENT` を `active` に変更する。
- admin bypass actor を組み立てる JSON helper を追加し、`RepositoryRole` admin (`actor_id=5`) を `pull_request` モードで ruleset に含める。
- `allowed_merge_methods` を repository settings に合わせて `merge` と `squash` のみに制限する。
- required status checks の JSON helper を追加するが、既定値は空配列のままにして path-filtered workflow を default required check にしない。

### 2. classic branch protection を ruleset 方針に揃える

- default branch 名を取得し、`gh api repos/<owner>/<repo>/branches/<default>/protection` へ PUT する。
- `required_conversation_resolution=false` を反映し、ユーザー要望どおり「レビューソリューションは解決しなくてもよい」状態へ揃える。
- `enforce_admins=false` と ruleset の PR-only bypass を組み合わせ、admin の direct push は ruleset で防ぎつつ、PR merge は自己責任で許可する。

### 3. 実リポジトリへ再適用して最終監査する

- `lazychezmoi` と `dotfiles` の両方に対して updated script を実行し、ruleset と classic branch protection を再取得する。
- `dotfiles` に残っている `master` ruleset は `conditions.ref_name.include=[]` を確認し、`main` には直接マッチしない残骸として扱う。
- `CODEOWNERS` ではなく admin bypass を採用する理由を、GitHub の ruleset / branch protection の仕様に基づいて整理する。

## 変更対象ファイル

- `dot_local/bin/executable_setup-github`
- `plan/dotfile-66.md`

## 検証方法

- `bash -n dot_local/bin/executable_setup-github`
- `bash dot_local/bin/executable_setup-github ryo246912/lazychezmoi`
- `bash dot_local/bin/executable_setup-github ryo246912/dotfiles`
- `gh api repos/ryo246912/lazychezmoi/rulesets/14373599`
- `gh api repos/ryo246912/lazychezmoi/branches/main/protection`
- `gh api repos/ryo246912/dotfiles/rulesets/11535739`
- `gh api repos/ryo246912/dotfiles/rulesets/3905723`
- `gh api repos/ryo246912/dotfiles/branches/main/protection`
- `gh api repos/ryo246912/lazychezmoi/contents/.github/workflows/lazychezmoi.yaml -q .content | base64 -d`
- `sed -n '1,220p' .github/workflows/lint.yaml`
- `sed -n '1,220p' .github/workflows/lint-action.yaml`

## リスクと未解決点

- `dotfiles` の `master` ruleset は now-safe だが残骸ではあるため、UI 上のノイズとしては別途削除余地がある。
- sandbox 制約で `.git/FETCH_HEAD` へ書き込めず、`git fetch` / `git merge origin/main` / commit / push 系の操作はこのセッションでは制限を受ける可能性がある。
