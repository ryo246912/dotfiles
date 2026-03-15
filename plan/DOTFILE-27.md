# DOTFILE-27 pr-create skill plan

## 概要

- `pr-create` という新しい shared skill を追加し、agent cli が現在のブランチを push して PR を作成するまでの手順を再利用可能にする
- PR 本文は各リポジトリの PR template と diff をもとに構築し、`変更内容概要` `実装理由` `確認項目` を含める
- コード差分を読めば明らかな内容は冗長に説明せず、非自明な設計意図や全体像だけを文章化する

## 要件

### 機能要件

- `pr-create` という名前で trigger しやすい shared skill を追加する
- 現在の repo / branch / upstream / working tree の状態を確認する preflight を定義する
- GitHub の一般的な PR template 配置を探索し、見つかった template を PR 本文の骨格として使う
- `git diff` `git diff --stat` `git log` などを根拠に PR 本文を組み立てる
- PR 本文では次を満たす
  - `変更内容概要` を簡潔にまとめる
  - `実装理由` で変更の意図や背景を書く
  - `確認項目` で reviewer が見るべき点や実施済み確認を列挙する
  - 自明なコード変更の言い換えは避ける
  - 全体像の把握が難しい変更だけ補足説明する
- branch の push と `gh pr create` を同じ workflow 内で扱う
- template 不在、upstream 未設定、branch が default branch より遅れている、差分が薄い場合の fallback を含める

### 非機能要件

- `claudecode` / `codexcli` の shared source として流用できる記述にする
- SKILL.md は簡潔に保ち、どうしても冗長になる場合だけ `scripts/` や `references/` を追加する
- 手順は imperative で書き、実行順序が曖昧にならないようにする

### 制約条件

- 正本は `dot_config/rulesync/.rulesync/skills/` 配下に置く
- repo 既存規約では `commands/` は geminicli 向けなので、Codex / Claude では skill として実装するのが自然
- この repo copy では generated output は追跡されておらず、source-of-truth の skill source を直接更新する
- この session では外部 `git fetch` が使えず、`origin/main` との同期確認はローカル参照までに限られる
- ユーザー指示により、実装前に plan 合意が必要

## 実装計画

### 1. skill の契約を定義する

- `dot_config/rulesync/.rulesync/skills/pr-create/SKILL.md` を新規追加する
- frontmatter に `name` と `description` を定義し、`pr-create` / `PR 作成` / `push して PR を作る` といった依頼で trigger しやすくする
- body では「preflight -> template 探索 -> diff 要約 -> push -> PR 作成 -> 最終確認」の順で流れを固定する

### 2. PR 本文生成 workflow を設計する

- preflight で以下を確認する
  - 現在の branch 名
  - working tree の clean / dirty
  - upstream の有無
  - default branch との差分状況
  - `gh` 利用可否
- PR template 探索ルールを定義する
  - `.github/pull_request_template.md`
  - `.github/PULL_REQUEST_TEMPLATE.md`
  - `docs/pull_request_template.md`
  - `docs/PULL_REQUEST_TEMPLATE.md`
  - repo root の `pull_request_template.md` / `PULL_REQUEST_TEMPLATE.md`
  - `.github/PULL_REQUEST_TEMPLATE/` 配下の複数 template
- 本文構築ルールを定義する
  - `git diff --stat` と主要 diff hunk から変更の塊を抽出する
  - `git log` や commit message から意図を補強する
  - 自明な rename や mechanical change は要約しすぎない
  - reviewer が理解しにくい変更にだけ説明を足す

### 3. push / PR 作成の実行手順を定義する

- upstream 未設定なら push 先を明示して `git push -u` を使う
- push 後に `gh pr create` で title / body / base を確定する
- body をそのまま送る前に、template の未記入項目や diff と矛盾する説明がないかを見直す
- template が見つからない場合は、skill 内で標準の section 構成を使う

### 4. rulesync 運用と検証手順を定義する

- source-of-truth は `dot_config/rulesync/.rulesync/skills/pr-create/` に限定して編集する
- この repo copy では generated output を戻す対象が無いため、source-only で完結させる
- 検証は以下を想定する
  - frontmatter と skill 構造の確認
  - `rulesync` / lint command の利用可否確認
  - 現在の repo を使った dry-run ベースの walkthrough

## 技術的課題と対応策

- `commands/` は geminicli 向けであり、ticket の「コマンド」をそのまま command artifact に落とすと repo 規約とずれる
  - 対応策: `pr-create` を shared skill 名として実装し、command 的な trigger は description で拾う
- PR template は repo ごとに配置差分がある
  - 対応策: common path の探索順を skill に明記し、複数 template は選択または明示的指定に fallback する
- PR 本文の品質は diff 解釈の質に依存する
  - 対応策: 「自明な変更は省く」「非自明な変更だけ理由を書く」という判定基準を skill に埋め込む
- branch が default branch より遅れている場合、古い差分理解で PR を作るリスクがある
  - 対応策: preflight に base branch との差分確認を入れ、必要なら同期を促す

## テスト計画

- skill source の frontmatter / path が既存 conventions に沿っていることを確認する
- `gh pr create --help` と `rulesync --version` が実行可能であることを確認する
- 現在の repo で template 探索コマンドを dry-run し、template あり / なし双方の fallback を確認する
- SKILL.md の手順が、dirty tree / upstream なし / template なし / base branch 遅れのケースをカバーしていることを確認する
- helper script を追加した場合は、その script を representative case で実行する

## デプロイ・リリース計画

- この ticket では plan 合意後に実装へ進む
- 実装では source 更新を優先し、rulesync の generate / re-add は repo 制約の範囲で扱う
- 完了時は Linear の workpad に検証結果と commit 情報を集約する

## リスクと未解決事項

- `git fetch` がこの session では使えないため、最新 `origin/main` との完全同期は implementation 開始時に再確認が必要

## 変更対象ファイル

- `dot_config/rulesync/.rulesync/skills/pr-create/SKILL.md`
- `plan/DOTFILE-27.md`

## 検証方法

- `rulesync --version`
- `gh pr create --help`
- `git rev-list --left-right --count HEAD...origin/main`
- `rg -n "targets:|description:" dot_config/rulesync/.rulesync/skills/pr-create/SKILL.md`
- `find . -maxdepth 4 \( -path './.github/pull_request_template.md' -o -path './.github/PULL_REQUEST_TEMPLATE.md' -o -path './docs/pull_request_template.md' -o -path './docs/PULL_REQUEST_TEMPLATE.md' -o -path './pull_request_template.md' -o -path './PULL_REQUEST_TEMPLATE.md' -o -path './.github/PULL_REQUEST_TEMPLATE/*.md' \) | sort`

## 参考資料

- `dot_config/rulesync/README.md`
- `dot_config/rulesync/.rulesync/skills/*`
- `/Users/ryo./.codex/skills/.system/skill-creator/SKILL.md`
