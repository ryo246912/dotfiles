# DOTFILE-122 rulesync の格納場所を .rulesync にする計画

## 概要

`dot_config/rulesync/exact_dot_rulesync` 配下に置かれている Rulesync の入力ツリーを、chezmoi で `$HOME/.rulesync` に配布される構成へ移す。

Rulesync 公式ドキュメントでは、ルール・hooks・skills・mcp などの入力は `.rulesync/` 配下を source of truth として扱う。一方、このリポジトリは chezmoi の source directory なので、`$HOME/.rulesync` に配布するための source 名は実ディレクトリ `.rulesync` ではなく `dot_rulesync` を使う。

現状、`dot_config/rulesync/exact_dot_rulesync` は `$HOME/.config/rulesync/.rulesync` に配布され、`dot_config/rulesync/rulesync.jsonc` は `$HOME/.config/rulesync/rulesync.jsonc` に配布される。レビュー指摘を踏まえ、Rulesync の入力ツリーだけでなく global 生成用 config も `$HOME/.rulesync` 側へ寄せる。

## 要件

### 機能要件

- Rulesync の canonical input tree を `$HOME/.rulesync` に配布できる source 構成にする。
- 現在 `dot_config/rulesync/exact_dot_rulesync` にある `hooks.json`、`mcp.json.tmpl`、`rules/COMMON.md`、`skills/**/SKILL.md` を移行対象にする。
- 現在 `dot_config/rulesync/rulesync.jsonc` にある global 生成用 config を `dot_rulesync/rulesync.jsonc` へ移す。
- 既存の `mise` タスク `rulesync-generate` が、移行後の `$HOME/.rulesync` を入力として global 生成できるようにする。
- 既存の project-local 用 `.rulesync/rules/CLAUDE.md` と root `rulesync.jsonc` は、今回の global 入力移行とは分けて扱う。

### 非機能要件

- chezmoi の source 命名規則に沿い、配布先パスが明確に追跡できる構成にする。
- Rulesync の最新ドキュメント上の概念に合わせ、`.rulesync/` を入力ツリー兼 global 生成用 config の置き場として扱う。
- 不要なリファクタリングや Rulesync 設定スキーマの全面移行は行わない。

### 制約条件

- 実装は計画承認後に行う。計画レビュー中はコード変更しない。
- devcontainer 内でのテスト・ビルド・パッケージインストールは実行しない。
- `mise trust` は実行しない。必要な検証は明示パスの `chezmoi` や `rg` を使って行う。
- kickoff sync として `git fetch origin main` を試したが、`.git/FETCH_HEAD` への書き込みが `Operation not permitted` で失敗した。計画作成は継続し、実装前にも再確認する。

## 調査結果

- `dot_config/rulesync/exact_dot_rulesync/hooks.json` は chezmoi 上で `$HOME/.config/rulesync/.rulesync/hooks.json` に展開される。
- `dot_config/rulesync/rulesync.jsonc` は `$HOME/.config/rulesync/rulesync.jsonc` に展開される。
- source root の `.rulesync/rules/CLAUDE.md` は `chezmoi managed` に出てこないため、 `$HOME/.rulesync` 配布の根拠にはできない。
- `chezmoi managed --path-style absolute` では、現状の Rulesync 入力は `$HOME/.config/rulesync/.rulesync/**` として管理されている。
- `dot_config/mise/config.toml` の `rulesync-generate` は、現在 `rulesync generate` と `cd ~/.config/rulesync && rulesync generate` を実行する。

## 実装方針

### 1. Rulesync 入力ツリーを `dot_rulesync` に移す

- `dot_config/rulesync/exact_dot_rulesync/hooks.json` を `dot_rulesync/hooks.json` へ移す。
- `dot_config/rulesync/exact_dot_rulesync/mcp.json.tmpl` を `dot_rulesync/mcp.json.tmpl` へ移す。
- `dot_config/rulesync/exact_dot_rulesync/rules/COMMON.md` を `dot_rulesync/rules/COMMON.md` へ移す。
- `dot_config/rulesync/exact_dot_rulesync/skills/**/SKILL.md` を `dot_rulesync/skills/**/SKILL.md` へ移す。
- `dot_config/rulesync/rulesync.jsonc` を `dot_rulesync/rulesync.jsonc` へ移す。
- 移行後、空になった `dot_config/rulesync/exact_dot_rulesync` は削除する。

### 2. global 生成タスクを移行先入力に合わせる

- `dot_config/mise/config.toml` の `rulesync-generate` を更新する。
- project-local 生成の `rulesync generate` は維持する。
- global 側は `cd ~ && rulesync generate --config ~/.rulesync/rulesync.jsonc --global` の形に変え、作業ディレクトリを `$HOME` にすることで `$HOME/.rulesync` を入力として使う。
- 実装時確認で Rulesync 8.2.0 の `generate` には `--input-root` が存在しないことを確認したため、`--config` 指定と `cd ~` の組み合わせに補正する。
- `features` 構造の大きな変更はせず、配置と参照パスだけを変える。

### 3. 補助ファイルの扱いを維持する

- `dot_config/rulesync/hooks/ai-rule-hook.md` は Rulesync 入力ツリーではなく、現状では devcontainer script の prompt template とは別の補助ファイルとして扱う。
- 参照がないため今回の移動対象からは外す。必要なら別チケットで整理する。

## 変更予定ファイル

- `dot_config/rulesync/exact_dot_rulesync/**`
  - `dot_rulesync/**` へ移動する。
- `dot_config/rulesync/rulesync.jsonc`
  - `dot_rulesync/rulesync.jsonc` へ移動する。
- `dot_config/mise/config.toml`
  - `rulesync-generate` の global 側コマンドを更新する。
- `plan/DOTFILE-122-rulesync-location.md`
  - 本計画ファイル。

## 検証方法

- 配置確認:
  - `find dot_rulesync -maxdepth 5 -type f -print`
  - `find dot_config/rulesync -maxdepth 5 -type f -print`
- chezmoi 管理対象確認:
  - `/Users/ryo./.local/share/mise/installs/aqua-twpayne-chezmoi/2.70.3/chezmoi --source /Users/ryo./Programming/ai/DOTFILE-122/dotfiles managed --path-style absolute | /opt/homebrew/bin/rg '(^|/)\\.rulesync(/|$)|(^|/)\\.config/rulesync(/|$)|rulesync\\.jsonc'`
- source-to-target 確認:
  - `/Users/ryo./.local/share/mise/installs/aqua-twpayne-chezmoi/2.70.3/chezmoi --source /Users/ryo./Programming/ai/DOTFILE-122/dotfiles target-path dot_rulesync/hooks.json`
  - 期待値は `$HOME/.rulesync/hooks.json`。
  - `/Users/ryo./.local/share/mise/installs/aqua-twpayne-chezmoi/2.70.3/chezmoi --source /Users/ryo./Programming/ai/DOTFILE-122/dotfiles target-path dot_rulesync/rulesync.jsonc`
  - 期待値は `$HOME/.rulesync/rulesync.jsonc`。
- 静的確認:
  - `git diff --check`
- 実行確認:
  - `rulesync generate --help` または `rulesync --version` で CLI が使えることを確認する。
  - 実際の `rulesync generate` は生成物を書き換える可能性があるため、実装時は dry-run 相当の手段がある場合のみ実行し、なければコマンド案として記録する。

## リスクと対応

- `dot_rulesync` と既存 source root の `.rulesync` が併存するため、役割が紛らわしい。
  - 対応: `dot_rulesync` は `$HOME/.rulesync` 配布用、source root の `.rulesync` は chezmoi source repo 内の project-local Rulesync 用として明記する。
- global mode のサポート範囲は Rulesync バージョンで差がある。
  - 対応: 今回は設定スキーマや対象 feature の全面見直しは行わず、入力ルート移行とコマンドの明示化に限定する。
- `git fetch origin main` が sandbox 権限で失敗している。
  - 対応: 実装前に再試行し、失敗する場合は workpad に証跡を残す。計画ファイル作成自体は継続する。

## 未決事項

- `dot_config/rulesync/hooks/ai-rule-hook.md` を今後どこへ置くべきか。
- source root の `.rulesync/rules/CLAUDE.md` と `$HOME/.rulesync/rules/COMMON.md` の役割分担を将来統合するか。
- Rulesync config を deprecated な `features` object から `targets` object へ移行するか。

## 参考資料

- Rulesync Configuration: https://rulesync.dyoshikawa.com/guide/configuration.html
- Rulesync Global Mode: https://rulesync.dyoshikawa.com/guide/global-mode.html
- Rulesync Separate Input Root: https://rulesync.dyoshikawa.com/guide/separate-input-root.html
- Rulesync File Formats: https://rulesync.dyoshikawa.com/reference/file-formats.html
